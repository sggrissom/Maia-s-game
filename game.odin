package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

Game_State :: struct {
    window_size: rl.Vector2,
    paddle: rl.Rectangle,
    ai_paddle: rl.Rectangle,
    paddle_speed: f32,
    ball: rl.Rectangle,
    ball_direction: rl.Vector2,
    ball_speed: f32,
    ai_target_y: f32,
    ai_reaction_delay: f32,
    ai_reaction_timer: f32,
    score_player: int,
    score_cpu: int,
    boost_timer: f32,
    current_screen: Screen,
    current_option: int,
}

Sound_Effect :: struct {
    hit: rl.Sound,
    win: rl.Sound,
	lose: rl.Sound,
}

Screen :: enum{TITLE, ONE_PLAYER, TWO_PLAYER, GAME_OVER}

ball_direction_calculate :: proc(ball: rl.Rectangle, paddle: rl.Rectangle) -> (rl.Vector2, bool)
{
    if rl.CheckCollisionRecs(ball, paddle) {
        ball_center := rl.Vector2 {
            ball.x + ball.width / 2,
            ball.y + ball.height / 2,
        }
        paddle_center := rl.Vector2 {
            paddle.x + paddle.width / 2,
            paddle.y + paddle.height / 2,
        }

        return linalg.normalize0(ball_center - paddle_center), true
    }
    return {}, false
}

reset :: proc (using gs: ^Game_State)
{
    angle := rand.float32_range(-45, 46)
    if rand.int_max(100) % 2 == 0 do angle += 180
    r := math.to_radians(angle)

    ball_direction.x = math.cos(r)
    ball_direction.y = math.sin(r)

    ball.x = window_size.x / 2 - ball.width / 2
    ball.y = window_size.y / 2 - ball.height / 2

    paddle_margin: f32 = 50

    paddle.x = window_size.x - (paddle.width + paddle_margin) 
    paddle.y = window_size.y / 2 - paddle.height / 2

    ai_paddle.x = paddle_margin
    ai_paddle.y = window_size.y / 2 - paddle.height / 2
}

apply_ai_to_paddle :: proc(using gs: ^Game_State, delta: f32) {
    ai_reaction_timer += delta
    if ai_reaction_timer >= ai_reaction_delay {
        ai_reaction_timer = 0
        ball_mid := ball.y + ball.height / 2
        if ball_direction.x < 0 {
            ai_target_y = ball_mid - ai_paddle.height / 2
            ai_target_y += rand.float32_range(-20, 20)
        } else {
            ai_target_y = window_size.y / 2 - ai_paddle.height / 2
        }
    }

    target_diff := ai_target_y - ai_paddle.y
    ai_paddle.y += linalg.clamp(target_diff, -paddle_speed, paddle_speed) * 0.65
    ai_paddle.y = linalg.clamp(ai_paddle.y, 0, window_size.y - ai_paddle.height)
}

game_logic :: proc(using gs: ^Game_State, sfx: ^Sound_Effect) {
    delta := rl.GetFrameTime()

    boost_timer -= delta

    //detect keyboard and moving paddle

    if rl.IsKeyDown(rl.KeyboardKey.UP) {
        paddle.y -= paddle_speed
    }
    if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
        paddle.y += paddle_speed
    }
    if rl.IsKeyDown(rl.KeyboardKey.SPACE) {
        if boost_timer < 0 {
            boost_timer = 0.2
        }
    }
    if rl.IsKeyDown(rl.KeyboardKey.B) {
        current_screen = Screen.TITLE
        score_cpu = 0
        score_player = 0
        reset(gs)
    }

    paddle.y = linalg.clamp(paddle.y, 0, window_size.y - paddle.height)

    if (current_screen == Screen.ONE_PLAYER) {
        apply_ai_to_paddle(gs, delta)
    } else if (current_screen == Screen.TWO_PLAYER) {
        if rl.IsKeyDown(rl.KeyboardKey.W) {
            ai_paddle.y -= paddle_speed
        }
        if rl.IsKeyDown(rl.KeyboardKey.S) {
            ai_paddle.y += paddle_speed
        }
        if rl.IsKeyDown(rl.KeyboardKey.SPACE) {
            if boost_timer < 0 {
                boost_timer = 0.2
            }
        }
    }

    // move the ball

    next_ball_rect := ball
    next_ball_rect.x += ball_speed * ball_direction.x
    next_ball_rect.y += ball_speed * ball_direction.y
    if next_ball_rect.y >= 720 - ball.height || next_ball_rect.y <= 0 {
        ball_direction.y *= -1
    }
    if next_ball_rect.x >= window_size.x - ball.width {
        score_cpu += 1
        rl.PlaySound(sfx.lose)
        reset(gs)
    }
    if next_ball_rect.x < 0 {
        score_player += 1
        rl.PlaySound(sfx.win)
        reset(gs)
    }

    if new_dir, ok := ball_direction_calculate(next_ball_rect, paddle); ok {
        if boost_timer > 0 {
            d := 1 + boost_timer / 0.2
            new_dir *= d
        }
        ball_direction = new_dir
        rl.PlaySound(sfx.hit)
    } else if new_dir, ok := ball_direction_calculate(next_ball_rect, ai_paddle); ok {
        if boost_timer > 0 {
            d := 1 + boost_timer / 0.2
            new_dir *= d
        }
        ball_direction = new_dir
        rl.PlaySound(sfx.hit)
    }


    ball.x += ball_speed * ball_direction.x
    ball.y += ball_speed * ball_direction.y
}

title_logic :: proc(using gs: ^Game_State) {
    if rl.IsKeyDown(rl.KeyboardKey.UP) {
        current_option -= 1
    }
    if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
        current_option += 1
    }
    if rl.IsKeyDown(rl.KeyboardKey.ENTER) {
        if current_option == 1 {
            current_screen = Screen.ONE_PLAYER
        } else if current_option == 2 {
            current_screen = Screen.TWO_PLAYER
        }
    }
    current_option = linalg.clamp(current_option, 1, 2)
}

render_title :: proc(using gs: ^Game_State) {
    rl.ClearBackground(rl.BLACK)

    menu_item_x := i32(window_size.x / 2) - 125

    rl.DrawText("Bruh", i32(window_size.x / 2) - 50, 50, 42, rl.GREEN)
    rl.DrawText("One Player", menu_item_x, 250, 32, rl.BLUE)
    rl.DrawText("Two Player", menu_item_x, 300, 32, rl.BLUE)
    if (current_option == 1) {
        rl.DrawCircle(menu_item_x - 25, 250 + 15, 5, rl.WHITE)
    } else if (current_option == 2) {
        rl.DrawCircle(menu_item_x - 25, 300 + 15, 5, rl.WHITE)
    }
}

render_game :: proc(using gs: ^Game_State) {
    rl.ClearBackground(rl.BLACK)

    if boost_timer > 0 {
        rl.DrawRectangleRec(paddle, {u8(255 * (0.2 / boost_timer)), 255, 255, 255})
        rl.DrawRectangleRec(ai_paddle, {u8(255 * (0.2 / boost_timer)), 255, 255, 255})
    } else {
        rl.DrawRectangleRec(paddle, rl.BLUE)
        rl.DrawRectangleRec(ai_paddle, rl.GREEN)
    }
    rl.DrawRectangleRec(ball, rl.PINK)
    
    rl.DrawText(fmt.ctprintf("{}", score_cpu), 12, 12, 32, rl.GREEN)
    rl.DrawText(fmt.ctprintf("{}", score_player), i32(window_size.x) - 28, 12, 32, rl.BLUE)
}

main :: proc() {
    gs := Game_State {
        window_size = {1280, 720},
        current_screen = Screen.TITLE,
        current_option = 0,
        paddle = {width = 30, height = 80},
        ai_paddle = {width = 30, height = 80},
        paddle_speed = 10,
        ball = {width = 30, height = 30},
        ball_speed = 10,
        ai_reaction_delay = 0.1,
    }
    reset(&gs)

    using gs

    rl.InitWindow(i32(window_size.x), i32(window_size.y), "bruh")
    rl.SetTargetFPS(60)
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    sfx := Sound_Effect {
        hit = rl.LoadSound("hit.wav"),
        win = rl.LoadSound("win.wav"),
        lose = rl.LoadSound("lose.wav"),
    }

    for !rl.WindowShouldClose() {
        if gs.current_screen == Screen.TITLE
        {
            title_logic(&gs)
            rl.BeginDrawing()
            render_title(&gs)
            rl.EndDrawing()
        } else if (gs.current_screen == Screen.ONE_PLAYER || gs.current_screen == Screen.TWO_PLAYER)
        {
            game_logic(&gs, &sfx)
            rl.BeginDrawing()
            render_game(&gs)
            rl.EndDrawing()
        }

        free_all(context.temp_allocator)
    }
}
