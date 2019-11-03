#include "rlc.h"
#include "../file_manipulation.h"

char* rlc(char* input_file) 
{ 
    input_file = read_file(input_file);
    
    int rLen; 
    char count[MAX_RLEN]; 
    int len = strlen(input_file); 
  
    char* dest = (char*)malloc(sizeof(char) * (len * 2 + 1)); 
  
    int i, j = 0, k; 
  
    // Traverse the input 
    for (i = 0; i < len; i++) { 
  
        /* Copy the first occurrence of the new character */
        dest[j++] = input_file[i]; 
  
        /* Count the number of occurrences of the new character */
        rLen = 1; 
        while (i + 1 < len && input_file[i] == input_file[i + 1]) { 
            rLen++; 
            i++; 
        } 
  
        /* Store rLen in a character array count[] */
        sprintf(count, "%d", rLen); 
  
        /* Copy the count[] to destination */
        for (k = 0; *(count + k); k++, j++) { 
            dest[j] = count[k]; 
        } 
    } 
  
    /*terminate the destination string */
    dest[j] = '\0'; 

    for (int i = 0; i < j; i++){
        printf("%c", dest[i]);
    }

    return dest; 
} 