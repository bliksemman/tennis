VIRTUAL_WIDTH = 320
VIRTUAL_HEIGHT = 240
WINDOW_WIDTH, WINDOW_HEIGHT = love.window.getDesktopDimensions()

PADDLE_SPEED = 64

PADDLE_WIDTH = 8
PADDLE_HEIGHT = 32
PADDLE_RADIUS = PADDLE_HEIGHT / 2

BALL_SIZE = 8
BALL_RADIUS = BALL_SIZE / 2
BALL_SPEED_INCREASE = 8

SERVE_SPEED = PADDLE_SPEED

local push = require("push")
local paddle_hit_snd = love.audio.newSource('paddle_hit.wav', 'static')
local wall_hit_snd = love.audio.newSource('wall_hit.wav', 'static')
local point_scored_snd = love.audio.newSource('point_scored.wav', 'static')

local font = love.graphics.newImageFont("font.png",
    " abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
       "123456789.,!?-+/():;%&`'*#=[]\"")
font:setFilter('nearest', 'nearest', 0)
local title_font = font

local game_state = {
   state = 'start',
   player_1 = {
      paddle_pos = VIRTUAL_HEIGHT / 2
   },
   player_2 = {
      paddle_pos = VIRTUAL_HEIGHT / 2
   },
   ball = {
      x = VIRTUAL_WIDTH / 2,
      y = VIRTUAL_HEIGHT / 2,
      x_velocity = 40,
      y_velocity = 0,
   }
}

-- State transitions
function prepare_round(game_state)
   game_state.state = 'serve'
   local ball = game_state.ball
   ball.x_velocity = 0
   ball.y_velocity = 0

   local start_pos = VIRTUAL_HEIGHT / 2
   game_state.player_1.paddle_pos = start_pos
   game_state.player_2.paddle_pos = start_pos
   
   if game_state.serving_player == 1 then
      ball.x = PADDLE_WIDTH + BALL_RADIUS
   else
      ball.x = VIRTUAL_WIDTH - PADDLE_WIDTH - BALL_RADIUS
   end
end

function start_game(game_state)
   game_state.serving_player = 1
   game_state.player_1.score = 0
   game_state.player_2.score = 0
   prepare_round(game_state)
end

function serve(game_state)
   game_state.state = 'play'
   local serve_speed = SERVE_SPEED
   if game_state.serving_player == 2 then
      serve_speed = -serve_speed
   end
   game_state.ball.x_velocity = serve_speed
end


-- Helpers
function is_ball_y_within_paddle(ball_y, paddle_y)
   return (ball_y - BALL_RADIUS) < (paddle_y + PADDLE_RADIUS) and
      (ball_y + BALL_RADIUS) > (paddle_y - PADDLE_RADIUS)
end

function update_ball(dt, game_state)
   local ball = game_state.ball
   ball.x = ball.x + ball.x_velocity * dt
   ball.y = ball.y + ball.y_velocity * dt
   -- Select the proper paddle
   local defending_player = game_state.player_2
   if ball.x_velocity < 0 then
      defending_player = game_state.player_1
   end
   -- Paddle bounce
   if is_ball_y_within_paddle(ball.y, defending_player.paddle_pos)
      and (
	 (ball.x_velocity > 0 and (ball.x + BALL_RADIUS) > (VIRTUAL_WIDTH - PADDLE_WIDTH))
	    or
	    (ball.x_velocity < 0 and (ball.x - BALL_RADIUS) < PADDLE_WIDTH))
   then
      -- Bounce the ball
      paddle_hit_snd:play()
      ball.y_velocity = (ball.y - defending_player.paddle_pos) / (PADDLE_HEIGHT / 2) * PADDLE_SPEED
      local x_velocity = math.abs(ball.x_velocity) + BALL_SPEED_INCREASE
      if ball.x_velocity > 0 then
	 x_velocity = -x_velocity
      end
      ball.x_velocity = x_velocity
   end
   --[[ Screen edge bounce (top & bottom)
        Makes sure to always bounce in the proper direction (regardless
        of paddle bounce). ]]--
   if ((ball.y - BALL_RADIUS) < 0) then
      wall_hit_snd:play()
      ball.y_velocity = math.abs(ball.y_velocity)
   elseif ((ball.y + BALL_RADIUS) > VIRTUAL_HEIGHT) then
      wall_hit_snd:play()
      ball.y_velocity = -math.abs(ball.y_velocity)
   end

end

function update_paddle_pos(dt, player_state, up_key, down_key)
   local paddle_pos = player_state.paddle_pos
   if love.keyboard.isDown(up_key) then
      paddle_pos = paddle_pos - PADDLE_SPEED * dt
   elseif love.keyboard.isDown(down_key) then
      paddle_pos = paddle_pos + PADDLE_SPEED * dt
   end
   player_state.paddle_pos = math.max(
      math.min(paddle_pos, VIRTUAL_HEIGHT - PADDLE_RADIUS),
      PADDLE_RADIUS)
end

local update_fns = {
   start = function (dt, game_state)
      update_ball(dt, game_state)
      
   end,
   serve = function (dt, game_state)
      update_paddle_pos(dt, game_state.player_1, 'a', 'z')
      update_paddle_pos(dt, game_state.player_2, 'k', 'm')

      local player = game_state.player_1
      if game_state.serving_player == 2 then
	 player = game_state.player_2
      end
      game_state.ball.y = player.paddle_pos
   end,
   play = function (dt, game_state)
      update_paddle_pos(dt, game_state.player_1, 'a', 'z')
      update_paddle_pos(dt, game_state.player_2, 'k', 'm')

      update_ball(dt, game_state)
      -- Ball goes off screen
      local attacking_player = game_state.player_1
      if ball.x_velocity < 0 then
	 attacking_player = game_state.player_2
      end
      if (ball.x + BALL_RADIUS) < 0 or (ball.x - BALL_RADIUS) > VIRTUAL_WIDTH then
	 point_scored_snd:play()
	 attacking_player.score = attacking_player.score + 1
	 game_state.serving_player = (game_state.serving_player % 2) + 1
	 prepare_round(game_state)
      end
   end,
}

function love.joystickpressed(joystick,button)
   print("JOY", button)
end

local render_fns = {
   start = function (game_state)
      render_paddles(game_state)
      render_ball(game_state)
      text = love.graphics.newText(font, 'Press space to start')
      love.graphics.draw(text, VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2, 0, 1, 1, text:getWidth() / 2, text:getHeight() / 2)
   end,
   serve = function (game_state)
      render_paddles(game_state)
      render_ball(game_state)
      love.graphics.setFont(font)
      love.graphics.printf('Press space to serve', 0, VIRTUAL_HEIGHT - 24, VIRTUAL_WIDTH, 'center')
      love.graphics.printf(game_state.player_1.score, 0, 24, VIRTUAL_WIDTH / 2, 'center')
      love.graphics.printf(game_state.player_2.score, VIRTUAL_WIDTH / 2,
			   24, VIRTUAL_WIDTH / 2, 'center')
   end,
   play = function (game_state)
      render_paddles(game_state)
      render_ball(game_state)      
   end
}

local key_handler_fns = {
   start = function (key, game_state)
      if key == 'space' then
	 start_game(game_state)
      end
   end,
   serve = function (key, game_state)
      if key == 'space' then
	 serve(game_state)
      end
   end,
   play = function (key, game_state)
   end,
}


function love.load ()
   push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
      fullscreen = true,
      resizable = false,
      vsync = true
   })
   love.graphics.setDefaultFilter('nearest', 'nearest', 0)
end

function love.update(dt)
   update_fns[game_state.state](dt, game_state)
end

function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end
   key_handler_fns[game_state.state](key, game_state)
end

function love.draw()
   push:apply('start')
   state = game_state.state
   render_fns[state](game_state)
   push:apply('end')
end

-- Render helper functions

function render_paddle(x, y)
   love.graphics.rectangle('fill', x, y - PADDLE_HEIGHT / 2, PADDLE_WIDTH, PADDLE_HEIGHT)
end

function render_paddles(game_state)
   render_paddle(0, game_state.player_1.paddle_pos)
   render_paddle(VIRTUAL_WIDTH - PADDLE_WIDTH, game_state.player_2.paddle_pos)
end

function render_ball(game_state)
   ball = game_state.ball
   love.graphics.rectangle('fill', ball.x - BALL_SIZE / 2, ball.y - BALL_SIZE / 2,
			   BALL_SIZE, BALL_SIZE)
end
