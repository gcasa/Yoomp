#ifndef YOOM_P_GAME_H
#define YOOM_P_GAME_H

#define GAME_LANES 12
#define GAME_STAGES 6

typedef enum
{
  TILE_NORMAL,
  TILE_HOLE,
  TILE_BOOST,
  TILE_SLOW,
  TILE_FINISH
} Tile;

typedef enum
{
  GAME_READY,
  GAME_RUNNING,
  GAME_PAUSED,
  GAME_CRASHED,
  GAME_OVER,
  GAME_STAGE_CLEAR,
  GAME_WON
} GameStatus;

typedef struct
{
  GameStatus status;
  unsigned int stage;
  unsigned int lives;
  unsigned int score;
  unsigned int checkpoint_score;
  double position;
  int lane;
  double height;
  double velocity;
  double speed;
  double slow_time;
  int last_scored_row;
} Game;

void game_reset (Game *game);
void game_action (Game *game);
void game_pause (Game *game);
void game_turn (Game *game, int direction);
void game_step (Game *game, double seconds);
Tile game_tile (unsigned int stage, int row, int lane);
int game_length (unsigned int stage);

#endif
