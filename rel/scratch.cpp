#include "scratch.h"

#include <mkb/mkb.h>
#include <cstring>
#include "pad.h"

#define ABS(x) ((x) < 0 ? (-x) : (x))

/*
 * Potential jump sounds:
 * 50
 * 52
 * 55
 * 268
 * 295
 * 500
 */

namespace mkb
{
extern "C"
{
void g_call_SoundReqID_arg_0(s32 id);
void spawn_effect(Effect *effect);
}

}

constexpr s32 JUMP_FRAMES = 15;

namespace scratch
{

static s32 s_jump_frames = 0;
static bool s_jumping = false;
static s32 s_ticks_since_jump_input = -1;
static s32 s_ticks_since_ground = -1;
static s32 s_ticks_since_jump = 1000;

static void reset()
{
    s_ticks_since_jump_input = -1;
    s_ticks_since_ground = -1;
    s_jumping = false;
    s_jump_frames = 0;
    s_ticks_since_jump = 1000;
}

void init()
{
    mkb::ball_friction = 0.027f;
    mkb::ball_restitution = 0.25f;
    reset();
}

void tick()
{
    if (mkb::sub_mode != mkb::SMD_GAME_READY_MAIN
        && mkb::sub_mode != mkb::SMD_GAME_PLAY_INIT
        && mkb::sub_mode != mkb::SMD_GAME_PLAY_MAIN
        && mkb::sub_mode != mkb::SMD_GAME_GOAL_INIT
        && mkb::sub_mode != mkb::SMD_GAME_GOAL_MAIN)
    {
        reset();
        return;
    }

    mkb::Ball &ball = mkb::balls[mkb::curr_player_idx];

    bool jump_pressed = pad::button_pressed(pad::BUTTON_A);
    bool ground_touched = ball.phys_flags & mkb::PHYS_G_ON_GROUND;

    if (jump_pressed)
    {
        s_ticks_since_jump_input = 0;
    }
    if (ground_touched)
    {
        s_ticks_since_ground = 0;
    }

    bool before = ground_touched && s_ticks_since_jump_input > -1 && s_ticks_since_jump_input < 3;
    bool after = jump_pressed && s_ticks_since_ground > -1 && s_ticks_since_ground < 7;
    bool go_buffered_press = mkb::sub_mode == mkb::SMD_GAME_PLAY_INIT && pad::button_down(pad::BUTTON_A);

    if (before || after || go_buffered_press) s_jumping = true;

    if (pad::button_released(pad::BUTTON_A))
    {
        s_jumping = false;
        s_jump_frames = 0;
        s_ticks_since_jump = 0;
    }

    if (s_jumping && s_jump_frames == 0)
    {
        mkb::g_call_SoundReqID_arg_0(268);
    }

    if (s_jumping)
    {
        s_jump_frames++;
        if (s_jump_frames > JUMP_FRAMES)
        {
            s_jumping = false;
            s_jump_frames = 0;
            s_ticks_since_jump = 0;
        }
    }

    if (s_jumping)
    {
        f32 lerp = static_cast<f32>(JUMP_FRAMES - s_jump_frames) / JUMP_FRAMES;
        lerp = lerp * lerp * lerp;
        ball.vel.y += lerp * 0.1;
    }

//    // Turn on ball sparkles while jumping
//    if (s_jumping || s_ticks_since_jump < 6)
//    {
//        s32 sparkles = -1;
//        if (s_jumping) sparkles = JUMP_FRAMES - s_jump_frames;
//        else sparkles = 1;
//        for (s32 i = 0; i < sparkles; i++)
//        {
//            mkb::Effect effect;
//            memset(&effect, 0, sizeof(effect));
//            effect.type = mkb::EFFECT_LEVITATE;
//            effect.g_ball_idx = ball.idx;
//            effect.g_pos.x = ball.pos.x;
//            effect.g_pos.y = ball.pos.y;
//            effect.g_pos.z = ball.pos.z;
//            mkb::spawn_effect(&effect);
//        }
//    }

    if (s_ticks_since_jump_input > -1)
    {
        s_ticks_since_jump_input++;
        if (s_ticks_since_jump_input >= 3) s_ticks_since_jump_input = -1;
    }

    if (s_ticks_since_ground > -1)
    {
        s_ticks_since_ground++;
        if (s_ticks_since_ground >= 7) s_ticks_since_ground = -1;
    }

    s_ticks_since_jump++;
    if (s_ticks_since_jump > 1000) s_ticks_since_jump = 1000;
}

}