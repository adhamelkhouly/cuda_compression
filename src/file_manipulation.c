#include "file_manipulation.h"

char* read_file(char *fileName) {
    FILE *file = fopen(fileName, "r");
    char *code;
    size_t n = 0;
    int c;

    if (file == NULL) {
        return NULL; //could not open file
    }

    fseek(file, 0, SEEK_END);
    long f_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    code = malloc(f_size);

    while ((c = fgetc(file)) != EOF) {
        code[n++] = (char)c;
    }

    code[n] = '\0';        
    
    for (int i = 0; i < f_size; i++) {
        printf("%c", code[i]);
    }

    return code;
}
