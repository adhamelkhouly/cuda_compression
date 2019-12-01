/*
 * This code is derived from geeksforgeeks.org for benchmarkig purposes
 * https://www.geeksforgeeks.org/run-length-encoding/
 */

#include "rlc.h"

char* rlc(char* input_str)
{
    int run_length;
    char count[MAX_RLEN];
    int len = strlen(input_str);

    char* dest = (char*)malloc(sizeof(char) * (len * 2 + 1));

    int i, j = 0, k;

    // Traverse the input
    for (i = 0; i < len; i++) {

        // Copy the first occurrence of the new character
        dest[j++] = input_str[i];

        // Count the number of occurrences of the new character
        run_length = 1;
        while (i + 1 < len && input_str[i] == input_str[i + 1]) {
            run_length++;
            i++;
        }

        // Copy Run length to a count[]
        sprintf(count, "%d", run_length);

        for (k = 0; *(count + k); k++, j++) {
            dest[j] = count[k];
        }
    }

    // Terminate string
    dest[j] = '\0';

    return dest;
}