#include<stdio.h>
#include<stdlib.h>
#include <unistd.h>
#include <string.h>
#include "interpreter.h"

int parseInput(char ui[]) {
    char tmp[1000];
    int a,b;
    char *words[1000] = {NULL}; 
    int w=0;

    // Skip white spaces
    for(a=0; ui[a]==' ' && a<1000; a++); 

    // Separate words by spaces
    while(ui[a] != '\0' && a<1000) {
        for(b=0; ui[a]!='\0' && ui[a]!=' ' && a<1000; a++, b++)
            tmp[b] = ui[a];
        tmp[b] = '\0';
        words[w] = strdup(tmp);
        a++; w++;
    }
    
    return interpreter(words);
}

int main(int argc, char const *argv[]) {
    int i, errorResult=0;
    char userInput[1000];
    printf("CUDA C/C++ Compression Application\n");
    printf("Version 0.1 - Created November 2020\n");
    printf("------------------------------------\n");

    while(1)
    {   
        // Input using keyboard and terminal
        if (isatty(STDIN_FILENO))
            printf("$");
        
        // Check that fget is not null
        char* check = fgets(userInput, sizeof(userInput), stdin);
        if (check == NULL) {
            freopen("/dev/tty", "r", stdin);
            continue;
        }
        // Strip trailing tokens
        userInput[strcspn(userInput, "\n")] = '\0';
        userInput[strcspn(userInput, "\r")] = '\0';

        // Input was redirected
        if (isatty(STDIN_FILENO) == 0) {
            printf("$%s\n", userInput);
        }

        errorResult = parseInput(userInput);

        // Error Message Handling
        if (errorResult == 1) {
            printf("Unknown command\n");
        }
        else if (errorResult == 6) {
            printf("help command does not take any additional arguments\n");
        }
        else if (errorResult == 7) {
            printf("quit command does not take any additional arguments\n");
        }
        else if (errorResult == 8) {
            printf("run command takes an argument\n");
        }
        else if (errorResult == 9) {
            printf("Script not found\n");
        }
    }

    return 0;
}