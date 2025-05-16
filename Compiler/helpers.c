#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TABLE_SIZE 100

/* Symbol table entry */
typedef struct {
    char* name;
    char* type;
    int scope;
    /* Add more attributes as needed */
} Symbol;

/* Symbol table */
Symbol symbol_table[TABLE_SIZE];
int symbol_count = 0;

/* Function to add a symbol to the table */
int add_symbol(char* name, char* type, int scope) {
    if (symbol_count >= TABLE_SIZE) {
        fprintf(stderr, "Symbol table overflow\n");
        return -1;
    }
    
    /* Check for redeclaration in the same scope */
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0 && symbol_table[i].scope == scope) {
            fprintf(stderr, "Redeclaration of variable %s\n", name);
            return -1;
        }
    }
    
    symbol_table[symbol_count].name = strdup(name);
    symbol_table[symbol_count].type = strdup(type);
    symbol_table[symbol_count].scope = scope;
    
    return symbol_count++;
}

/* Function to look up a symbol in the table */
int lookup_symbol(char* name, int scope) {
    /* First check in the current scope */
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0 && symbol_table[i].scope == scope) {
            return i;
        }
    }
    
    /* Then check in the global scope (0) */
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0 && symbol_table[i].scope == 0) {
            return i;
        }
    }
    
    return -1;  /* Symbol not found */
}

/* Generate a label name */
char* gen_label() {
    static int label_count = 0;
    char* label = (char*)malloc(10);
    sprintf(label, "L%d", label_count++);
    return label;
}

/* Generate code for binary operations */
char* gen_binary_op(char* left, char* op, char* right) {
    char* temp = new_temp();
    char* code = (char*)malloc(100);
    sprintf(code, "%s = %s %s %s\n", temp, left, op, right);
    return code;
}


/* Generate code for conditional jumps */
char* gen_conditional_jump(char* left, char* relop, char* right, char* label) {
    char* code = (char*)malloc(100);
    sprintf(code, "if %s %s %s goto %s\n", left, relop, right, label);
    return code;
}

/* Generate code for unconditional jumps */
char* gen_unconditional_jump(char* label) {
    char* code = (char*)malloc(50);
    sprintf(code, "goto %s\n", label);
    return code;
}

/* Generate code for array access */
char* gen_array_access(char* array, char* index) {
    char* temp = new_temp();
    char* code = (char*)malloc(100);
    sprintf(code, "%s = %s[%s]\n", temp, array, index);
    return code;
}
