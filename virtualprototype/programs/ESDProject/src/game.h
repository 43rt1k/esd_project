#ifndef GAME_H
#define GAME_H

#include <stdint.h>

typedef enum {
    UP,
    DOWN,
    LEFT,
    RIGHT
} Direction;

#define FIELD_WIDTH     12
#define FIELD_HEIGHT    10
#define SNAKE_MAX_LENGTH 5

#define EMPTY_CELL 0
#define SNAKE_CELL 1

typedef struct {
    int x;
    int y;
} SnakeSegment;

void updateSnakeGame(int8_t field[FIELD_WIDTH][FIELD_HEIGHT],
                     Direction command);

#endif /* GAME_H */
