%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Error reporting function for the parser
void yyerror(const char *s);
extern int yylex();
extern FILE *yyin;

// --- 3AC Generation Utilities ---

int temp_var_count = 0;   // Counter for temporary variables (t0, t1, ...)
int label_count = 0;      // Counter for labels (L0, L1, ...)

// Function to generate a new temporary variable name
char* new_temp() {
    char* temp = (char*)malloc(10);
    sprintf(temp, "t%d", temp_var_count++);
    return temp;
}

// Function to generate a new label name
char* new_label() {
    char* label = (char*)malloc(10);
    sprintf(label, "L%d", label_count++);
    return label;
}

// Function to print generated 3AC code
void emit(const char* code) {
    printf("%s", code);
}
%}

/* --- Semantic Value Types --- */
%union {
    int intval;    // For integer values (NUM)
    char* strval;  // For identifiers (ID)
    struct {
        char* code; // Holds generated 3AC code for this subtree
        char* addr; // Holds the address (variable/temp) representing the value
    } expr;
}

/* --- Token Declarations (Terminals) --- */
%token <strval> ID
%token <intval> NUM
%token INT IF ELSE WHILE RETURN
%token PLUS MINUS MULT DIV ASSIGN EQ NEQ LT GT LTE GTE
%token SEMICOLON COMMA LBRACE RBRACE LPAREN RPAREN

/* --- Non-terminal Type Declarations --- */
%type <expr> expr term factor rel_expr
%type <expr> stmt stmt_block decl_list decl return_stmt

%start program

%%

/* --- Grammar Rules Start Here --- */

// The main entry point: parses a C-style main function with declarations, statements, and a return
program
    : INT ID LPAREN RPAREN LBRACE decl_list stmt_block return_stmt RBRACE
      { 
        // Output the generated 3AC for declarations, statements, and return
        emit($6.code); 
        emit($7.code); 
        emit($8.code); 
      }
    ;

// Handles a (possibly empty) list of variable declarations
decl_list
    : /* empty */ { $$.code = strdup(""); }
    | decl_list decl { 
        // Concatenate code from previous declarations and this one
        $$.code = (char*)malloc(strlen($1.code) + strlen($2.code) + 1);
        sprintf($$.code, "%s%s", $1.code, $2.code);
    }
    ;

// Handles a single variable declaration (e.g., int a, b;)
decl
    : INT id_list SEMICOLON { $$.code = strdup(""); }
    ;

// Handles a comma-separated list of identifiers in declarations
id_list
    : ID
    | id_list COMMA ID
    ;

// Handles a (possibly empty) block of statements
stmt_block
    : /* empty */ { $$.code = strdup(""); }
    | stmt_block stmt { 
        // Concatenate code from previous statements and this one
        $$.code = (char*)malloc(strlen($1.code) + strlen($2.code) + 1);
        sprintf($$.code, "%s%s", $1.code, $2.code);
    }
    ;

// Handles all supported statements: assignment, if-else, if, while
stmt
    // Assignment: ID = expr;
    : ID ASSIGN expr SEMICOLON {
        // Generate 3AC for the right-hand side, then assign to the variable
        char* code = (char*)malloc(strlen($3.code) + 50);
        sprintf(code, "%s%s = %s\n", $3.code, $1, $3.addr);
        $$.code = code;
    }
    // If-Else statement
    | IF LPAREN rel_expr RPAREN LBRACE stmt_block RBRACE ELSE LBRACE stmt_block RBRACE {
        // Generate labels for true, false, and end branches
        char* ltrue = new_label();
        char* lfalse = new_label();
        char* lend = new_label();
        char* code = (char*)malloc(2048);
        // 3AC: if (cond) goto ltrue; goto lfalse; ltrue: ... goto lend; lfalse: ... lend:
        sprintf(code, "%sif (%s) goto %s\ngoto %s\n%s:\n%s goto %s\n%s:\n%s%s:\n",
            $3.code, $3.addr, ltrue, lfalse,
            ltrue, $6.code, lend,
            lfalse, $10.code, lend);
        $$.code = code;
    }
    // If statement (no else)
    | IF LPAREN rel_expr RPAREN LBRACE stmt_block RBRACE {
        char* ltrue = new_label();
        char* lend = new_label();
        char* code = (char*)malloc(1024);
        // 3AC: if (cond) goto ltrue; goto lend; ltrue: ... lend:
        sprintf(code, "%sif (%s) goto %s\ngoto %s\n%s:\n%s%s:\n",
            $3.code, $3.addr, ltrue, lend,
            ltrue, $6.code, lend);
        $$.code = code;
    }
    // While loop
    | WHILE LPAREN rel_expr RPAREN LBRACE stmt_block RBRACE {
        char* lstart = new_label();
        char* lbody = new_label();
        char* lend = new_label();
        char* code = (char*)malloc(2048);
        // 3AC: lstart: cond; if cond goto lbody; goto lend; lbody: ... goto lstart; lend:
        sprintf(code, "%s:\n%sif (%s) goto %s\ngoto %s\n%s:\n%s goto %s\n%s:\n",
            lstart, $3.code, $3.addr, lbody, lend,
            lbody, $6.code, lstart, lend);
        $$.code = code;
    }
    ;

// Handles a return statement: return expr;
return_stmt
    : RETURN expr SEMICOLON {
        // Generate 3AC for the return value
        char* code = (char*)malloc(strlen($2.code) + 50);
        sprintf(code, "%sreturn %s\n", $2.code, $2.addr);
        $$.code = code;
    }
    ;

// Handles arithmetic expressions with + and -
expr
    : expr PLUS term {
        // Generate 3AC: t = left + right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s + %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr MINUS term {
        // Generate 3AC: t = left - right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s - %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | term {
        // Single term, just propagate
        $$.addr = $1.addr;
        $$.code = $1.code;
    }
    ;

// Handles arithmetic expressions with * and /
term
    : term MULT factor {
        // Generate 3AC: t = left * right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s * %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | term DIV factor {
        // Generate 3AC: t = left / right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s / %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | factor {
        // Single factor, just propagate
        $$.addr = $1.addr;
        $$.code = $1.code;
    }
    ;

// Handles variables, numbers, and parenthesized expressions
factor
    : ID {
        // Variable: just use its name
        $$.addr = strdup($1);
        $$.code = strdup("");
    }
    | NUM {
        // Number: use as immediate value
        $$.addr = (char*)malloc(20);
        sprintf($$.addr, "%d", $1);
        $$.code = strdup("");
    }
    | LPAREN expr RPAREN {
        // Parenthesized expression: propagate
        $$.addr = $2.addr;
        $$.code = $2.code;
    }
    ;

// Handles relational expressions for conditions
rel_expr
    : expr LT expr {
        // t = left < right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s < %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr GT expr {
        // t = left > right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s > %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr EQ expr {
        // t = left == right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s == %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr NEQ expr {
        // t = left != right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s != %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr LTE expr {
        // t = left <= right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s <= %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    | expr GTE expr {
        // t = left >= right
        $$.addr = new_temp();
        $$.code = (char*)malloc(strlen($1.code) + strlen($3.code) + 50);
        sprintf($$.code, "%s%s%s = %s >= %s\n", $1.code, $3.code, $$.addr, $1.addr, $3.addr);
    }
    ;

%%

// Error reporting function for the parser
void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
    exit(1);
}

// Main function: opens input file (if provided) and starts parsing
int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *input = fopen(argv[1], "r");
        if (!input) {
            perror(argv[1]);
            return 1;
        }
        yyin = input;
    }
    yyparse();
    return 0;
}
