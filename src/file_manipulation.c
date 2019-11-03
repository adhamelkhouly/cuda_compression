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

    return code;
}

int write_file(char *file_name, char* output_str) {
   FILE *file_address;
   file_address = fopen(file_name, "w");
   int i;
   int len = strlen(output_str);

   if (file_address != NULL) {
	for (i = 0; i < len; i++) {
	   fputc (output_str[i], file_address);
       /* Add a new line every 100 characters*/
       if (i > 0 && (i % 100) == 0){
           fputc ('\n', file_address);
       }    
	}

	printf("File written successfully!\n");
	fclose(file_address);		
   }
   else {
  	  return 8;
   }
   return 0;
}

int generate_file(int size) {
  srand(time(0)); 
  FILE *fptr = fopen("test.txt", "w"); 

  int lower, upper;

  // ASCII lower and upper limits
  lower = 33;
  upper = 126;

  for (int i = 0; i < 1024 ; i++) {
    fprintf(fptr,"%c", rand() % (upper - lower + 1) + lower); 
     if (i > 0 && (i % 100) == 0){
           fputc ('\n', fptr);
       }  
  }

  fclose(fptr);
  return 0;
}