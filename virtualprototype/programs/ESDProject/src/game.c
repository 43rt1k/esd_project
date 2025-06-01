#include <stdint.h>
#include <string.h>
#include "game.h"

static SnakeSegment snakeBody[SNAKE_MAX_LENGTH];
static int snake_length = 0;
static Direction current_dir;
static int game_initialized = 0;

static void resetGame(int8_t field[FIELD_WIDTH][FIELD_HEIGHT]) {
    for (int x = 0; x < FIELD_WIDTH; ++x) {
        for (int y = 0; y < FIELD_HEIGHT; ++y) {
            field[x][y] = EMPTY_CELL;
        }
    }
    snake_length = 1;
    snakeBody[0].x = FIELD_WIDTH / 2;
    snakeBody[0].y = FIELD_HEIGHT / 2;
    field[ snakeBody[0].x ][ snakeBody[0].y ] = SNAKE_CELL;
    current_dir = RIGHT;
    game_initialized = 1;
}

void updateSnakeGame(int8_t field[FIELD_WIDTH][FIELD_HEIGHT],
                     Direction command)
{
    if (!game_initialized) {
        resetGame(field);
        current_dir = command;
    }
    if ((command == UP    && current_dir != DOWN)  ||
        (command == DOWN  && current_dir != UP)    ||
        (command == LEFT  && current_dir != RIGHT) ||
        (command == RIGHT && current_dir != LEFT))
    {
        current_dir = command;
    }
    SnakeSegment head = snakeBody[snake_length - 1];
    SnakeSegment newHead = head;
    switch (current_dir) {
        case UP:    newHead.y -= 1; break;
        case DOWN:  newHead.y += 1; break;
        case LEFT:  newHead.x -= 1; break;
        case RIGHT: newHead.x += 1; break;
    }
    if (newHead.x < 0 || newHead.x >= FIELD_WIDTH ||
        newHead.y < 0 || newHead.y >= FIELD_HEIGHT) {
        resetGame(field);
        return;
    }
    if (field[ newHead.x ][ newHead.y ] == SNAKE_CELL) {
        resetGame(field);
        return;
    }
    if (snake_length < SNAKE_MAX_LENGTH) {
        snakeBody[ snake_length ] = newHead;
        snake_length++;
    }
    field[ newHead.x ][ newHead.y ] = SNAKE_CELL;
    if (snake_length >= SNAKE_MAX_LENGTH) {
        resetGame(field);
    }
}
