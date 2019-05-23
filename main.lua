io.stdout:setvbuf('no') --afficher dans la console pendant l'execution
love.graphics.setDefaultFilter("nearest") --for pixel art game
if arg[#arg] == "-debug" then require("mobdebug").start() end --permet de debug pas a pas dans zerobrane

function initGame()
  playerButton1Down = false
  grid = {}
  grid.xNumber = 10
  grid.yNumber = 8
  grid.xStart = width/2 /2
  grid.yStart = height/4
  grid.xSize = (width-grid.xStart*2) / grid.xNumber
  grid.ySize = (height-grid.yStart) / grid.yNumber
  
  for i=1,grid.yNumber do
    grid[i] = {}
    for j=1,grid.xNumber do
      grid[i][j] = createRandomCell()
    end
  end
  
  selectedTab = {}
  minCellNeeded = 3
end

function printGridInfo()
  for i,line in ipairs(grid) do
    for j,item in ipairs(line) do
      print(i,j,item)
    end
  end
  print(grid.xStart,grid.yStart,grid.xSize,grid.ySize)
end

--recupere couleur,row,column à la position de la souris sur la grille
--return: tableau{couleur,row,column}
function getColorAtMouse()
  local mouseX,mouseY = love.mouse.getX(),love.mouse.getY()
  local row = math.floor((mouseY-grid.yStart)/grid.ySize)+1
  local column = math.floor((mouseX-grid.xStart)/grid.xSize)+1
  local color
  if row<1 or row>grid.yNumber or column<1 or column>grid.xNumber then
    color = "undefined"
  else
    color = grid[row][column]
  end
  local result = {}
  result.color = color
  result.row = row
  result.column = column
  return result
end

--Chemin le plus court entre 2 cellule (pas direct mais colonne et ligne)
--donc minimum 1 si deux cellules adjacentes, 2 si deux cellules diagonales etc..
--parametres:cell1{row,column},cell2{row,column}
--return: distance (int)
function getDistance2Cell(cell1Row,cell1Col,cell2Row,cell2Col)
  local activeCell = {row=cell1Row,column=cell1Col}
  local endCell = {row=cell2Row,column=cell2Col}
  local distance = 0
  while activeCell.row~=endCell.row or activeCell.column~=endCell.column do
    distance = distance + 1
    if activeCell.row < endCell.row then--si cellule active au-dessus
      local diffRow = endCell.row - activeCell.row
      if activeCell.column < endCell.column then --si cellule active a gauche
        local diffCol = endCell.column - activeCell.column
        if diffRow >= diffCol then
          activeCell.row = activeCell.row + 1
        else
          activeCell.column = activeCell.column + 1
        end
      else --si cellule acti a droite ou au meme niveau
        local diffCol = activeCell.column - endCell.column
        if diffRow >= diffCol then
          activeCell.row = activeCell.row + 1
        else
          activeCell.column = activeCell.column - 1
        end
      end
    elseif activeCell.row >= endCell.row then--si cellule active en-dessous
      local diffRow = activeCell.row - endCell.row
      if activeCell.column < endCell.column then --si cellule active a gauche
        local diffCol = endCell.column - activeCell.column
        if diffRow >= diffCol then
          activeCell.row = activeCell.row - 1
        else
          activeCell.column = activeCell.column + 1
        end
      else --si cellule active a droite ou au meme niveau
        local diffCol = activeCell.column - endCell.column
        if diffRow >= diffCol then
          activeCell.row = activeCell.row - 1
        else
          activeCell.column = activeCell.column - 1
        end
      end
    end
  end
  return distance
end

--Creer la couleur random pour une cellule
function createRandomCell()
  local number = math.random(1,4)
  color = ""
  if number == 1 then
    color = 'r'
  elseif number == 2 then
    color = 'b'
  elseif number == 3 then
    color = 'j'
  elseif number == 4 then
    color = 'v'
  end
  return color
end

--Fonction de rafraichissement de la grille
--Après une selection reussi de plusieurs cellule
function refreshGrid()
  local lowestRow=2
  local highestRow=grid.yNumber
  local leftCol=grid.xNumber
  local rightCol=1 --on initialise a l'envers
  for i,item in ipairs(selectedTab) do --on recupere seulement la zone a refresh
    if item.row > lowestRow then lowestRow=item.row end
    if item.row < highestRow then highestRow=item.row end
    if item.column < leftCol then leftCol=item.column end
    if item.column > rightCol then rightCol=item.column end
  end
  -- on boucle sur l'interval en partant du bas de la grille
  for i=lowestRow,2,-1 do
    for j=leftCol,rightCol do
      if grid[i][j]=="undefined" then
        -- si la cell est indefini on fait descendre la premiere cell au dessus d'elle
        local row = i-1
        while grid[row][j]=="undefined" do
          if row == 1 then break end
          row = row-1
        end
        --on fait descendre la premiere cell au dessus et on la vide
        grid[i][j]=grid[row][j]
        grid[row][j]="undefined"
      end
    end
  end
  --on boucle pour remettre des cases randoms dans les cases indefinis
  for i=(lowestRow-highestRow+1),1,-1 do
    for j=leftCol,rightCol do
      if grid[i][j]=="undefined" then
        grid[i][j]=createRandomCell()
      end
    end
  end
end

--Function qui gere l'action du joueur
--quand il selectionne des cellules par exemple ou quand il relache la souris
function playerMove()
  local cell = getColorAtMouse()
  if playerButton1Down and cell.row>0 and cell.row<=grid.yNumber and cell.column>0 and cell.column<=grid.xNumber then
    if love.mouse.isDown(1) then --clic gauche activé avant et maintenu
      --on ajoute a selectedTab si la cellule y est pas déjà
      local cellCanBeAdded = true
      local isClose = false
      for i=#selectedTab,1,-1 do
        item = selectedTab[i]
        if (item.column==cell.column and item.row==cell.row) or cell.color~=selectedTab[1].color then
          cellCanBeAdded = false
        end
        if cellCanBeAdded then
          if getDistance2Cell(item.row,item.column,cell.row,cell.column)==1 then
            isClose = true
          end
        end
      end
      if cellCanBeAdded and isClose then
        table.insert(selectedTab,cell)
      end
    else --clic gauche activé avant et relaché ce deltaTime
      --on supprime toutes les selected si 3 cells selectionnés, puis on vide selectedTab
      if #selectedTab >= minCellNeeded then
        for i,item in ipairs(selectedTab) do
          grid[item.row][item.column] = "undefined"
        end
        --on modifie la grille pour faire descendre les cases supprimés
        refreshGrid()
      end
      playerButton1Down = false
      for k,v in pairs(selectedTab) do selectedTab[k]=nil end
    end
  else
    if love.mouse.isDown(1) and cell.row>0 and cell.row<=grid.yNumber and cell.column>0 and cell.column<=grid.xNumber then --clic gauche desactivé et activé ce DT
      table.insert(selectedTab,cell)
      playerButton1Down = true
    end
  end
  
end

function love.load()
  love.window.setMode(800,450)
  width,height = love.window.getMode()
  math.randomseed(os.time())
  
  initGame()
  printGridInfo()
end

function love.update(dt)
  playerMove()
end

function love.draw()
  --affichage de la grille avec les couleurs respectives
  for i,line in ipairs(grid) do
    for j,item in ipairs(line) do
      if item == 'r' then love.graphics.setColor(255,0,0,255)
      elseif item == 'b' then love.graphics.setColor(0,0,255,255)
      elseif item == 'v' then love.graphics.setColor(0,255,0,255)
      elseif item == 'j' then love.graphics.setColor(255,255,0,255)
      elseif item == 'undefined' then love.graphics.setColor(50,50,50,255) end
      love.graphics.rectangle('fill',grid.xStart+(j-1)*grid.xSize,grid.yStart+(i-1)*grid.ySize,grid.xSize,grid.ySize)
    end
  end
  
  love.graphics.setColor(255,255,255,255)
  love.graphics.print(getColorAtMouse().color,0,0)
  --affichage du contour des cases en cours de selection
  for i,item in ipairs(selectedTab) do
    love.graphics.print(i..": "..item.row..";"..item.column,0,i*20)
    love.graphics.rectangle('line',grid.xStart+(item.column-1)*grid.xSize,grid.yStart+(item.row-1)*grid.ySize,grid.xSize,grid.ySize)
    
  end
end

function love.keyboard(key)
  
end