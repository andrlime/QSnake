using GameZero
using Colors

HEIGHT = 420
WIDTH = 620
BACKGROUND = colorant"#CCCCCC"

# Colors
RED = colorant"#FF0000"
GREEN = colorant"#00FF00"
BLUE = colorant"#0000FF"
YELLOW = colorant"#FFFF00"
DARK = colorant"#333333"

# Objects
struct Position
    x::Int64
    y::Int64
end

# Initial values
sizetile = 10
#ratefood = 0.1 commented because food spawns one at a time
snake = [Position(40,40)]
food = []
dx = 0
dy = 0
points = 0
lose = false
enable_keyboard_input = false

function move(dx::Int64, dy::Int64) # updates the snake
    global snake
    global food
    global points
    # need to test if the tile is food
    currenttile = snake[1]
    nexttile = Position(currenttile.x+dx, currenttile.y+dy)
    if nexttile.x == food[1].x && nexttile.y == food[1].y
        if length(snake) == 1
            snake = cat([nexttile], [currenttile],dims=1)
        else
            snake = cat([nexttile], snake,dims=1)
        end

        points += 1
        food = []
    else
        if length(snake) == 1
            snake = [nexttile]
        else
            # compute next tile
            # new snake positions = newtile + snake positions[0:-1]
            snake = cat([nexttile], snake[1:length(snake)-1],dims=1)
        end
    end
end

function update(_::Game)
    global snake
    global food
    global dx
    global dy
    # draw each tile of the snake
    for tile in snake
        draw(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), YELLOW)
    end

    for tile in food
        draw(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), RED)
    end
end

function gameover(snake::Vector{Position})
    for tile in snake
        # if out of bounds, return true
        if tile.x < 1 || tile.x > 40 || tile.y < 1 || tile.y > 40
            return true
        end

        # if any tile appears twice, return true
        uniques = Set(snake)
        if length(uniques) != length(snake)
            return true
        end
    end
    return false
end

function draw(g::Game)
    fill(DARK)
    draw(Rect(10, 10, 2*HEIGHT-20, 2*HEIGHT-20), BACKGROUND)
    text = (TextActor("$points points", "arial.ttf"; font_size=24, color=Int[255,255,0,255]))
    text.pos = (1100, 10)
    draw(text)

    if lose
        # draw the snake and food for good measure
        global snake
        global food
        for tile in snake
            draw(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), YELLOW)
        end
    
        for tile in food
            draw(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), RED)
        end
    else
        if length(food) == 0
            # generate food
            rand_x = rand((1:WIDTH/20), 1)[1]
            rand_y = rand((1:WIDTH/20), 1)[1]
            food = [Position(Int64(rand_x), Int64(rand_y))]
        end

        global snake
        global food
        global points
        global lose        

        if gameover(snake)
            # stop the game
            lose = true
            println("$points POINTS")
            return points
        end
        
        if g.keyboard.DOWN && enable_keyboard_input
            move(0, 1)
        elseif g.keyboard.UP && enable_keyboard_input
            move(0, -1)
        elseif g.keyboard.LEFT && enable_keyboard_input
            move(-1, 0)
        elseif g.keyboard.RIGHT && enable_keyboard_input
            move(1, 0)
        end

        # implement q learning


        update(g)
    end

    return nothing
end