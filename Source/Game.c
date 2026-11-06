#include "Game.h"

#include <math.h>

#define GRAVITY 13.0
#define BOUNCE 3.0

static const struct
{
  int length;
  int interval;
  int width;
  double speed;
} stages[GAME_STAGES] =
{
  { 48, 8, 3, 5.0 },
  { 64, 7, 4, 5.4 },
  { 76, 6, 5, 5.8 },
  { 88, 6, 6, 6.2 },
  { 100, 5, 7, 6.6 },
  { 116, 5, 8, 7.1 }
};

int
game_length (unsigned int stage)
{
  return stages[stage].length;
}

static int
wrap_lane (int lane)
{
  return (lane % GAME_LANES + GAME_LANES) % GAME_LANES;
}

void
game_turn (Game *game, int direction)
{
  if (game->status == GAME_RUNNING)
    game->lane = wrap_lane (game->lane + direction);
}

Tile
game_tile (unsigned int stage, int row, int lane)
{
  int section;
  int offset;
  int relative;

  if (row >= game_length (stage))
    return row < game_length (stage) + 2 ? TILE_FINISH : TILE_HOLE;
  if (row < 8)
    return TILE_NORMAL;

  section = (row - 8) / stages[stage].interval;
  offset = (row - 8) % stages[stage].interval;
  relative = wrap_lane (lane - section * 2 - (int) stage * 3);

  if (offset == 2 || (offset == 3 && stage >= 2))
    {
      if (relative < stages[stage].width)
        return TILE_HOLE;
    }
  if (offset == 1 && relative == stages[stage].width)
    return TILE_BOOST;
  if (offset == 4 && relative == GAME_LANES - 1)
    return TILE_SLOW;
  return TILE_NORMAL;
}

static void
start_stage (Game *game)
{
  game->status = GAME_RUNNING;
  game->position = 0.5;
  game->lane = 0;
  game->height = 0.0;
  game->velocity = BOUNCE;
  game->speed = stages[game->stage].speed;
  game->slow_time = 0.0;
  game->last_scored_row = -1;
}

void
game_reset (Game *game)
{
  game->stage = 0;
  game->lives = 3;
  game->score = 0;
  game->checkpoint_score = 0;
  start_stage (game);
  game->status = GAME_READY;
}

void
game_action (Game *game)
{
  switch (game->status)
    {
    case GAME_READY:
    case GAME_CRASHED:
      start_stage (game);
      break;
    case GAME_STAGE_CLEAR:
      ++game->stage;
      game->checkpoint_score = game->score;
      start_stage (game);
      break;
    case GAME_OVER:
    case GAME_WON:
      game_reset (game);
      start_stage (game);
      break;
    case GAME_PAUSED:
      game->status = GAME_RUNNING;
      break;
    case GAME_RUNNING:
      break;
    }
}

void
game_pause (Game *game)
{
  if (game->status == GAME_RUNNING)
    game->status = GAME_PAUSED;
  else if (game->status == GAME_PAUSED)
    game->status = GAME_RUNNING;
}

static void
land (Game *game)
{
  int row;
  Tile tile;

  row = (int) floor (game->position);
  tile = game_tile (game->stage, row, game->lane);
  if (tile == TILE_HOLE)
    {
      --game->lives;
      game->score = game->checkpoint_score;
      game->status = game->lives ? GAME_CRASHED : GAME_OVER;
      return;
    }

  if (row > game->last_scored_row)
    {
      game->score += (tile == TILE_BOOST || tile == TILE_SLOW) ? 30 : 10;
      game->last_scored_row = row;
    }
  if (tile == TILE_SLOW)
    game->slow_time = 1.6;
  game->velocity = tile == TILE_BOOST ? 4.7 : BOUNCE;
}

static void
advance (Game *game, double seconds)
{
  game->position += game->speed * seconds;
  game->slow_time = fmax (0.0, game->slow_time - seconds);
}

void
game_step (Game *game, double seconds)
{
  double landing;
  double finish;
  double elapsed;

  while (seconds > 0.0 && game->status == GAME_RUNNING)
    {
      game->speed = stages[game->stage].speed;
      if (game->slow_time > 0.0)
        game->speed *= 0.62;
      landing = (game->velocity
                 + sqrt (game->velocity * game->velocity
                         + 2.0 * GRAVITY * game->height)) / GRAVITY;
      finish = (game_length (game->stage) - game->position) / game->speed;
      elapsed = fmin (seconds, fmin (landing, finish));
      if (game->slow_time > 0.0)
        elapsed = fmin (elapsed, game->slow_time);

      advance (game, elapsed);
      game->height = fmax (0.0, game->height + game->velocity * elapsed
                           - 0.5 * GRAVITY * elapsed * elapsed);
      game->velocity -= GRAVITY * elapsed;
      seconds -= elapsed;

      if (elapsed == finish)
        {
          game->score += 100;
          game->status = game->stage + 1 == GAME_STAGES
                         ? GAME_WON : GAME_STAGE_CLEAR;
        }
      else if (elapsed == landing)
        {
          game->height = 0.0;
          land (game);
        }
    }
}
