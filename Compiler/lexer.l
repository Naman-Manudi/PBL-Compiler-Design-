%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
%}

%option noyywrap

DIGIT      [0-9]
ID         [a-zA-Z_][a-zA-Z0-9_]*

%%

"int"           { return INT; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }
"return"        { return RETURN; }
{ID}            { yylval.strval = strdup(yytext); return ID; }
{DIGIT}+        { yylval.intval = atoi(yytext); return NUM; }
"=="            { return EQ; }
"!="            { return NEQ; }
"<="            { return LTE; }
">="            { return GTE; }
"<"             { return LT; }
">"             { return GT; }
"="             { return ASSIGN; }
"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MULT; }
"/"             { return DIV; }
";"             { return SEMICOLON; }
","             { return COMMA; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
[ \t\r\n]+      { /* skip whitespace */ }
.               { printf("Unrecognized character: %s\n", yytext); }

%%
