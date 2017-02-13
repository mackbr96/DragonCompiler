%{
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "tree.h"
#include "hash.h"
#include "y.tab.h"
int yydebug = 1;

int yywrap() { return 1; }
void yyerror(const char *str) { fprintf(stderr, "error: %s\n", str); }
int main() 
{ 
	global_table = (table_t*)create_table();
	yyparse();
}
%}

%define parse.error verbose
%define parse.lac full

/* create union to hold value of current token */
%union {
	int ival;
	float fval;
	char *opval;
	char *sval;

	tree_t *tval;
}

/* number tokens */
%token <ival> INUM
%token <fval> RNUM

/* operator tokens */
%token <opval> ADDOP	/* 	+ - or 			*/
%token <opval> MULOP	/* 	* / and 		*/
%token <opval> RELOP	/* 	< > = <= >= <> 	*/
%token <opval> ASSOP	/* 	:= 				*/
%token <opval> NOT		/* 	not 			*/

%token <opval> ARRAYOP	/* 	[] 				*/
%token <opval> PARENOP	/* 	() 				*/
%token <opval> LISTOP	/* 	, ; : _ 		*/

/* identifier token */
%token <sval> IDENT
%token <sval> STRING

/* general keyword tokens */
%token <sval> PROGRAM
%token <sval> FUNCTION
%token <sval> PROCEDURE

/* variable and array keyword tokens */
%token <sval> VAR
%token <sval> ARRAY OF
%token <sval> DOTDOT
%token <sval> INTEGER
%token <sval> REAL

/* control flow keyword tokens */
%token <sval> BEG END
%token <sval> IF THEN ELSE
%token <sval> DO WHILE
%token <sval> FOR DOWNTO TO
%token <sval> REPEAT UNTIL

/* empty token */
%token <sval> EMPTY

/* variables must also return correct value type */
%type <tval> start
%type <tval> program
%type <tval> ident_list
%type <tval> decls
%type <tval> type
%type <tval> std_type
%type <tval> subprogram_decls
%type <tval> subprogram_decl
%type <tval> subprogram_head
%type <tval> header
%type <tval> param_list
%type <tval> param
%type <tval> compound_stmt
%type <tval> opt_stmts
%type <tval> stmt_list
%type <tval> stmt
%type <tval> var
%type <tval> procedure_stmt
%type <tval> expr_list
%type <tval> expr
%type <tval> simple_expr
%type <tval> term
%type <tval> factor
%type <tval> id

/* order here specifies precedence */
%left ASSOP
%left ADDOP
%left MULOP
%left RELOP
%left NOT

%right THEN ELSE /* choose closest if statement */

/* set starting variable */
%start start

%%

start
	: program
		{
			fprintf(stderr, "\n\n\nSYNTAX TREE\n___________\n\n");
			print_tree($1, 0);
		}

program
	: PROGRAM id '(' ident_list ')' ';' decls subprogram_decls compound_stmt '.'
		{
			$$ = op_tree(LISTOP, "_",
					op_tree(LISTOP, "_", 
						op_tree(LISTOP, ";",
							op_tree(PARENOP, "()", $2, $4),
						$7),
					$8),
				 $9);
		}
	;

ident_list
	: id
		{ $$ = $1; }
	| ident_list ',' id
		{ $$ = op_tree(LISTOP, ",", $1, $3); }
	;

decls		/* for some reason, not taking this rule? */
	: decls VAR ident_list ':' type ';'
		{
			$$ = op_tree(LISTOP, ":",
					op_tree(VAR, $2, $1, $3),
				 $5);
		}
	| /* empty */
		{ $$ = empty_tree(); }
	;

type
	: std_type
		{ $$ = $1; }
	| ARRAY '[' INUM DOTDOT INUM ']' OF std_type
		{ 
			$$ = str_tree(OF, $7, 
					op_tree(ARRAYOP, "[]", str_tree(ARRAY, $1, NULL, NULL),
						op_tree(DOTDOT, $4, int_tree(INUM, $3, NULL, NULL), int_tree(INUM, $5, NULL, NULL))
					)
				 , $8); 
		}
	;

std_type
	: INTEGER
		{ $$ = str_tree(INTEGER, $1, NULL, NULL); }
	| REAL
		{ $$ = str_tree(REAL, $1, NULL, NULL); }
	;

subprogram_decls
	: subprogram_decls subprogram_decl ';'
		{ op_tree(LISTOP, "_", $1, $2); }
	| /* empty */
		{ $$ = empty_tree(); }
	;

subprogram_decl
	: subprogram_head decls subprogram_decls compound_stmt
		{
			$$ = op_tree(LISTOP, "_", $1, 
					op_tree(LISTOP, "_", $2, 
						op_tree(LISTOP, "_", $3, $4)
					)
				 );
		}
	;

subprogram_head
	: FUNCTION header ':' std_type ';'
		{ $$ = str_tree(FUNCTION, $1, $2, $4); }
	| PROCEDURE header ';'
		{ $$ = $2; }
	;

header
	: id '(' param_list ')'
		{ $$ = op_tree(PARENOP, "()", $1, $3); }
	| id
		{ $$ = $1; }
	;

param_list
	: param
		{ $$ = $1; }
	| param_list ';' param
		{ $$ = op_tree(LISTOP, ";", $1, $3); }
	;

param
	: ident_list ':' type
		{ $$ = op_tree(LISTOP, ":", $1, $3); }
	;

compound_stmt
	: BEG opt_stmts END
		{ $$ = $2; }
	;

opt_stmts
	: stmt_list
		{ $$ = $1; }
	| /* empty */
		{ $$ = empty_tree(); }
	;

stmt_list
	: stmt
		{ $$ = $1; }
	| stmt_list ';' stmt
		{ $$ = op_tree(LISTOP, ";", $1, $3); }
	;

stmt
	: var ASSOP expr
		{ $$ = op_tree(ASSOP, $2, $1, $3); }
	| procedure_stmt
		{ $$ = $1; }
	| compound_stmt
		{ $$ = $1; }
	| IF expr THEN stmt
		{ $$ = str_tree(IF, "i-t", $2, $4); }
	| IF expr THEN stmt ELSE stmt
		{ $$ = str_tree(IF, "i-te", $2, str_tree(IF, "t-e", $4, $6)); }
	| WHILE expr DO stmt
		{ $$ = str_tree(WHILE, $1, $2, $4); }
	| REPEAT stmt UNTIL expr
		{ $$ = str_tree(REPEAT, $1, $2, $4); }
	| FOR var ASSOP expr TO expr DO stmt
		{
			$$ = str_tree(FOR, $1,
					op_tree(ASSOP, $3, $2, $4),
					str_tree(TO, $5, $6, $8)
				);
		}
	| FOR var ASSOP expr DOWNTO expr DO stmt
		{
			$$ = str_tree(FOR, $1,
					op_tree(ASSOP, $3, $2, $4),
					str_tree(DOWNTO, $5, $6, $8)
				);
		}
	;

var
	: id
		{ $$ = $1; }
	| id '[' expr ']'
		{ $$ = op_tree(ARRAYOP, "[]", $1, $3); }
	;

procedure_stmt
	: id
		{ $$ = $1; }
	| id '(' expr_list ')'
		{ $$ = op_tree(PARENOP, "()", $1, $3); }
	;

expr_list
	: expr
		{ $$ = $1; }
	| expr_list ',' expr
		{ $$ = op_tree(LISTOP, ",", $1, $3); }
	;

expr
	: simple_expr
		{ $$ = $1; }
	| expr RELOP simple_expr 			/* allow multiple relops */
		{ $$ = op_tree(RELOP, $2, $1, $3); }
	;

simple_expr
	: term
		{ $$ = $1; }
	| ADDOP term						/* optional sign */ 
		{ $$ = str_tree(ADDOP, $1, $2, NULL); }
	| simple_expr ADDOP term
		{ $$ = op_tree(ADDOP, $2, $1, $3); }
	| STRING							/* ? */
		{ $$ = str_tree(STRING, $1, NULL, NULL); }
	;

term
	: factor
		{ $$ = $1; }
	| term MULOP factor
		{ $$ = op_tree(MULOP, $2, $1, $3); }
	;

factor
	: id
		{ $$ = $1; }
	| id '[' expr ']'
		{ $$ = op_tree(ARRAYOP, "[]", $1, $3); }
	| id '(' expr_list ')'
		{ $$ = op_tree(PARENOP, "()", $1, $3); }
	| INUM
		{ $$ = int_tree(INUM, $1, NULL, NULL); }
	| RNUM
		{ $$ = float_tree(RNUM, $1, NULL, NULL); }
	| '(' expr ')'
		{ $$ = $2; }
	| NOT factor
		{ $$ = str_tree(NOT, $1, $2, NULL); }
	;

id
	: IDENT
		{ $$ = str_tree(IDENT, $1, NULL, NULL); }
	;

%%
