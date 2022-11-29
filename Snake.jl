using GameZero
using Colors
using Distributions

HEIGHT = 420
WIDTH = 420
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
snake = [Position(20,20), Position(20,21), Position(20,22)]
rand_x_iii = rand((1:WIDTH/20), 1)[1]
rand_y_iii = rand((1:WIDTH/20), 1)[1]
food = [Position(Int64(rand_x_iii), Int64(rand_y_iii))]
dx = 0
dy = 0
points = 0
lose = false
enable_keyboard_input = false
generation = 0
fitnesses::Vector{Int64} = []

function move(snake::Vector{Position}, food::Vector{Position}, dx::Int64, dy::Int64) # updates the snake
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

    return (snake, food)
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

tick = 0
function draw(g::Game)
    global tick
    tick += 1
    fill(DARK)
    draw(Rect(10, 10, 2*HEIGHT-20, 2*HEIGHT-20), BACKGROUND)
    #text = (TextActor("$points points", "arial.ttf"; font_size=24, color=Int[255,255,0,255]))
    #text.pos = (1100, 10)
    #draw(text)

    if lose
        # draw the snake and food for good measure
        global snake
        global food
        for tile in snake
            fill(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), YELLOW)
        end
    
        for tile in food
            fill(Rect(2*tile.x*10, 2*tile.y*10, sizetile*2, sizetile*2), RED)
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
            println("$generation, $points")
            global generation
            generation += 1
            push!(fitnesses, points)

            # TODO: need to reset the game and output the score to a spreadsheet
            snake = [Position(20,20), Position(20,21), Position(20,22)]
            rand_x_iv = rand((1:WIDTH/20), 1)[1]
            rand_y_iv = rand((1:WIDTH/20), 1)[1]
            food = [Position(Int64(rand_x_iv), Int64(rand_y_iv))]
            global dx
            global dy
            global points
            dx = 0
            dy = 0
            points = 0
            lose = false
        end
        
        if g.keyboard.DOWN && enable_keyboard_input
            s, f = move(snake, food, 0, 1)
            snake = s
            food = f
        elseif g.keyboard.UP && enable_keyboard_input
            s, f = move(snake, food, 0, -1)
            snake = s
            food = f
        elseif g.keyboard.LEFT && enable_keyboard_input
            s, f = move(snake, food, -1, 0)
            snake = s
            food = f
        elseif g.keyboard.RIGHT && enable_keyboard_input
            s, f = move(snake, food, 1, 0)
            snake = s
            food = f
        elseif g.keyboard.F
            global fitnesses
            print(fitnesses)
        end

        # implement q learning
        if tick % 5 == 0
            mx, my = Q(snake, food)
            s, f = move(snake, food, mx, my)
            snake = s
            food = f
        end

        update(g)
    end

    return nothing
end

struct GameState
   dangerup::Bool
   dangerdown::Bool
   dangerleft::Bool
   dangerright::Bool
   foodrelx::Int64
   foodrely::Int64
   gameover::Bool
end
function GameState(snake::Vector{Position}, food::Vector)
    dangerup::Bool = (Position(snake[1].x, snake[1].y-1) in snake) || (snake[1].y-1 < 1)
    dangerdown::Bool = (Position(snake[1].x, snake[1].y+1) in snake) || (snake[1].y+1 > 40)
    dangerleft::Bool = (Position(snake[1].x-1, snake[1].y) in snake) || (snake[1].x-1 < 1)
    dangerright::Bool = (Position(snake[1].x+1, snake[1].y) in snake) || (snake[1].x+1 > 40)
    foodrelx = 0
    foodrely = 0
    if length(food) != 0
        foodrelx = (food[1].x - snake[1].x) > 0 ? 1 : (food[1].x - snake[1].x) < 0 ? -1 : 0
        foodrely = (food[1].y - snake[1].y) > 0 ? 1 : (food[1].y - snake[1].y) < 0 ? -1 : 0
    end

    return GameState(dangerup, dangerdown, dangerleft, dangerright, foodrelx, foodrely, gameover(snake))
end

struct Movement
    dx::Int64
    dy::Int64
    score::Int64
end

QMap = Dict{GameState, Movement}()
epsilon = 0.1 # will change

function Q(snake, food) # returns a tuple
    current_state = GameState(snake, food) # need to fill this in
    randomnumber = rand(Uniform(0,1))
    action = nothing
    global epsilon

    if randomnumber < epsilon
        rand_x = (rand(0:1)*2)-1
        rand_y = (rand(0:1)*2)-1
        rand_z = (rand(0:1)*2)-1
        if rand_z == -1
            action = (0, rand_y)
        else   
            action = (rand_x, 0)
        end
    else
        if current_state in keys(QMap)
            if QMap[current_state].score < 0
                rand_x = (rand(0:1)*2)-1
                rand_y = (rand(0:1)*2)-1
                rand_z = (rand(0:1)*2)-1
                if rand_z == -1
                    action = (0, rand_y)
                else   
                    action = (rand_x, 0)
                end
            else
                movement = QMap[current_state]
                action = (movement.dx, movement.dy)
            end
        else
            rand_x = (rand(0:1)*2)-1
            rand_y = (rand(0:1)*2)-1
            rand_z = (rand(0:1)*2)-1
            if rand_z == -1
                action = (0, rand_y)
            else   
                action = (rand_x, 0)
            end
        end
    end

    # has the action, now do it
    supd, fupd = move(snake, food, action[1], action[2])
    next_state = GameState(supd, fupd)

    score = 0
    # calculate score difference for two states and update the q map

    if action[2] == -1 && !current_state.dangerup && next_state.dangerup
        score+=1
    end

    if action[2] == 1 && !current_state.dangerdown && next_state.dangerdown
        score+=1
    end

    if action[1] == -1 && !current_state.dangerleft && next_state.dangerleft
        score+=1
    end

    if action[1] == 1 && !current_state.dangerleft && next_state.dangerleft
        score+=1
    end

    # now i need to find the actual distances
    if length(food) == 0
        cfrelx = 0
        cfrely = 0
    else
        cfrelx = (food[1].x - snake[1].x)
        cfrely = (food[1].y - snake[1].y)
    end

    if length(fupd) == 0
        frelx = 0
        frely = 0
    else
        frelx = (fupd[1].x - supd[1].x)
        frely = (fupd[1].y - supd[1].y)
    end

    if abs(cfrelx) > abs(frelx)
        score+=1
    end

    if abs(cfrely) > abs(frely)
        score+=1
    end

    if abs(frelx) == 0 && abs(frely) == 0
        score+=10000
    end

    if next_state.gameover
        score -= 1000000
    end

    if score > 0
        if epsilon - 0.01 > 0
            epsilon -= 0.01
        end
    else
        if epsilon + 0.01 < 1
            epsilon += 0.01
        end
    end

    cs = nothing
    if current_state in keys(QMap)
        cs = QMap[current_state]
        if score > cs.score
            QMap[current_state] = Movement(action[1], action[2], score)
        else
            randomnumber = rand(Uniform(0,1))
            if randomnumber < epsilon/10 # might occasionally try new things
                QMap[current_state] = Movement(action[1], action[2], score)
            end
        end
    else
        cs = (0, 0, 0)
        if score > cs[3]
            QMap[current_state] = Movement(action[1], action[2], score)
        else
            randomnumber = rand(Uniform(0,1))
            if randomnumber < epsilon/10 # might occasionally try new things
                QMap[current_state] = Movement(action[1], action[2], score)
            end
        end
    end

    return action
end