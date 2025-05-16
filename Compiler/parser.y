%{
/* C declarations */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Symbol table and 3AC generation functions */
void yyerror(const char *s);
extern int yylex();
extern FILE *yyin;

/* Variables for 3AC generation */
int temp_var_count = 0;
int label_count = 0;
char temp_var_name[10];

/* Function prototypes for 3AC generation */
char* new_temp();
int new_label();
void emit(char *op, char *arg1, char *arg2, char *result);
%}

/* Yacc definitions */
%union {
    int intval;
    char *strval;
    struct expr_info {
        char *addr;  /* Address for 3AC */
        char *code;  /* Code for 3AC */
    } expr;
}

%token <intval> NUM
%token <strval> ID
%token INT FLOAT CHAR IF ELSE WHILE RETURN
%token PLUS MINUS MULT DIV ASSIGN
%token EQ NEQ LT GT LTE GTE
%token SEMICOLON LBRACE RBRACE LPAREN RPAREN

%type <expr> expr term factor statement assignment declaration statements program

%start program

%%
/* Yacc grammar rules */

program: statements
        {
            printf("// 3AC Generated Successfully\n");
            printf("%s", $1.code);
        }
        ;

statements: statement
        {
            $$.code = $1.code;
        }
        | statements statement
        {
            $$.code = (char*)malloc(strlen($1.code) + strlen($2.code) + 1);
            sprintf($$.code, "%s%s", $1.code, $2.code);
        }
        ;

statement: assignment SEMICOLON
        {
            $$.code = $1.code;
        }
        | declaration SEMICOLON
        {
            $$.code = $1.code;
        }
        /* Add rules for if, while, etc. */
        ;

declaration: INT ID
        {
            $$.code = (char*)malloc(50);
            sprintf($$.code, "// Declare int %s\n", $2);
            /* Add to symbol table */
        }
        /* Add rules for other types */
        ;

assignment: ID ASSIGN expr
        {
            $$.code = (char*)malloc(strlen($3.code) + 50);
            sprintf($$.code, "%s%s = %s\n", $3.code, $1, $3.addr);
        }
        ;

expr: expr PLUS term
    {
        char* temp = new_temp();
        $$.addr = temp;
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 100);
        sprintf($$.code, "%s%s%s = %s + %s\n", $1.code, $3.code, temp, $1.addr, $3.addr);
    }
    | expr MINUS term
    {
        char* temp = new_temp(); 
        $$.addr = temp;
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 100);
        sprintf($$.code, "%s%s%s = %s - %s\n", $1.code, $3.code, temp, $1.addr, $3.addr);
    }
    | term
    {
        $$.addr = $1.addr;
        $$.code = $1.code;
    }
    ;

term: term MULT factor
    {
        char* temp = new_temp();
        $$.addr = temp;
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 100);
        sprintf($$.code, "%s%s%s = %s * %s\n", $1.code, $3.code, temp, $1.addr, $3.addr);
    }
    | term DIV factor
    {
        char* temp = new_temp();
        $$.addr = temp;
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 100);
        sprintf($$.code, "%s%s%s = %s / %s\n", $1.code, $3.code, temp, $1.addr, $3.addr);
    }
    | factor
    {
        $$.addr = $1.addr;
        $$.code = $1.code;
    }
    ;

factor: ID
      {
          $$.addr = $1;
          $$.code = (char*)malloc(10);
          $$.code[0] = '\0';  /* Empty string */
      }
      | NUM
      {
          $$.addr = (char*)malloc(20);
          sprintf($$.addr, "%d", $1);
          $$.code = (char*)malloc(10);
          $$.code[0] = '\0';  /* Empty string */
      }
      | LPAREN expr RPAREN
      {
          $$.addr = $2.addr;
          $$.code = $2.code;
      }
      ;

%%

/* Additional C code for 3AC generation */
char* new_temp() {
    sprintf(temp_var_name, "t%d", temp_var_count++);
    return strdup(temp_var_name);
}

int new_label() {
    return label_count++;
}

void emit(char *op, char *arg1, char *arg2, char *result) {
    if (arg2)
        printf("%s = %s %s %s\n", result, arg1, op, arg2);
    else
        printf("%s = %s %s\n", result, op, arg1);
}

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
    exit(1);
}

int main(int argc, char **argv) {
    if(argc > 1) {
        if(!(yyin = fopen(argv[1], "r"))) {
            perror(argv[1]);
            return 1;
        }
    }
    yyparse();
    return 0;
}
