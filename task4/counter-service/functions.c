#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "civetweb.h"

#include "functions_map.h"

#define MAX_QUERY_LEN 128


static int counter = 1;

int get_and_increment_counter(const char* query_str, char* response_dest, int response_max_len, int* response_len) {
    int resp_len = snprintf(response_dest, response_max_len, "%d", counter);
    counter++;
    *response_len = resp_len;
    return 1;
}

int get_counter(const char* query_str, char* response_dest, int response_max_len, int* response_len) {
    int resp_len = snprintf(response_dest, response_max_len, "%d", counter);
    *response_len = resp_len;
    return 1;
}

int reset_counter(const char* query_str, char* response_dest, int response_max_len, int* response_len) {
    counter = 1;
    int resp_len = snprintf(response_dest, response_max_len, "%d", counter);
    *response_len = resp_len;
    return 1;
}

FUNCTION_MAPS(
    DEFINE_FUNC_MAP("/get_and_increment_counter", get_and_increment_counter);
    DEFINE_FUNC_MAP("/get_counter", get_counter);
    DEFINE_FUNC_MAP("/reset_counter", reset_counter);
)





