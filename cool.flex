/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed"); 
char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;
int  string_buf_size = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_depth = 0;
#define ENTER_MLCOMMENT()  do { BEGIN(COMMENT); comment_depth++; } while (0)

#define strlit_putc(c)                                    \
do {                                                      \
  string_buf_size++;                                      \
  if (string_buf_size > MAX_STR_CONST) {                  \
    string_buf_ptr = string_buf;                          \
    string_buf_size = 0;                                  \
    cool_yylval.error_msg = "String constant too long";   \
    return ERROR;                                         \
  }                                                       \
  *string_buf_ptr++ = c;                                  \
} while (0)

%}

/*
 * Define names for regular expressions here.
 */

%x COMMENT
%x STRING
%x ERROR_TO_NEWLINE
%x ERROR_TO_ENDQUOTE
%x ERROR_TO_ENDSTRING

DARROW          =>
ASSIGN          <-
LE              <=
DIGIT           [0-9]
ID              [a-z][a-zA-Z0-9_]*
TYPE            [A-Z][a-zA-Z0-9_]*

%%

 /*
  *  Nested comments
  */
<INITIAL>"(*" { ENTER_MLCOMMENT(); }

<COMMENT>"(*" {
  // Ensure were not going from -- to (*
  if (comment_depth > 0)
    ENTER_MLCOMMENT();
}

<COMMENT>\*\) {
  // Handle both single line and multi line cases.
  // if comment_depth is 0 but were in COMMENT, then were in a single line comment
  if (comment_depth == 0 || --comment_depth == 0) {
    BEGIN(INITIAL);
  } else if (comment_depth < 0)
    return (ERROR);
}

<COMMENT>\n { 
  curr_lineno++;
  // Check for terminated single line comment
  if (comment_depth == 0)
    BEGIN(INITIAL);
}

<INITIAL>\*\) {
  cool_yylval.error_msg = "Unmatched *)";
  return ERROR;
}

<COMMENT><<EOF>>   {
  BEGIN(INITIAL);
  if (comment_depth) {
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
  }
}

<INITIAL>--                     { BEGIN(COMMENT); }

 /*
  *  The multiple-character operators.
  */
{DARROW}		                    { return (DARROW); }
{ASSIGN}                        { return (ASSIGN); }
{LE}                            { return (LE);     }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)                      { return (CLASS); }
(?i:else)                       { return (ELSE);  }
(?i:fi)                         { return (FI);    }
(?i:if)                         { return (IF);    }
(?i:in)                         { return (IN);    }
(?i:inherits)                   { return (INHERITS); }
(?i:isvoid)                     { return (ISVOID); }
(?i:let)                        { return (LET);   }
(?i:loop)                       { return (LOOP);  }
(?i:pool)                       { return (POOL);  }
(?i:then)                       { return (THEN);  }
(?i:while)                      { return (WHILE); }
(?i:case)                       { return (CASE);  }
(?i:esac)                       { return (ESAC);  }
(?i:new)                        { return (NEW);   }
(?i:of)                         { return (OF);    }
(?i:not)                        { return (NOT);   }

t(?i:rue)     {
  cool_yylval.boolean = true;
  return (BOOL_CONST);
}

f(?i:alse)    {
  cool_yylval.boolean = false;
  return (BOOL_CONST);
}

{DIGIT}+ {
  cool_yylval.symbol = inttable.add_string(yytext);
  return (INT_CONST);
}

{ID} {
  cool_yylval.symbol = stringtable.add_string(yytext);
  return (OBJECTID);
}

{TYPE} {
  cool_yylval.symbol = stringtable.add_string(yytext);
  return (TYPEID);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\" {
  BEGIN(STRING);
  string_buf_ptr = string_buf;
  string_buf_size = 0;
}

<STRING>\" {
  BEGIN(INITIAL);
  strlit_putc('\0');
  cool_yylval.symbol = stringtable.add_string(string_buf);
  return (STR_CONST);
}

<STRING>\n         {
  curr_lineno++;
  cool_yylval.error_msg =  "Unterminated string constant";
  BEGIN(INITIAL);
  return ERROR;
}
<STRING>\\n             { curr_lineno++; strlit_putc('\n'); }
<STRING>\\\n            { curr_lineno++; strlit_putc('\n'); }
<STRING>\\              strlit_putc('\\');
<STRING>\\t             strlit_putc('\t');
<STRING>\\b             strlit_putc('\b');
<STRING>\\f             strlit_putc('\f');
<STRING>\\[a-zA-Z0-9]   strlit_putc(yytext[1]);
<STRING>\0  {
  cool_yylval.error_msg =  "String contains null character";
  BEGIN(ERROR_TO_ENDSTRING);
  return ERROR;
}
<STRING>\\\0  {
  cool_yylval.error_msg =  "String contains escaped null character";
  BEGIN(ERROR_TO_ENDSTRING);
  return ERROR;
}

<STRING>\\.        strlit_putc(yytext[1]);
<STRING>.          strlit_putc(yytext[0]);
<STRING><<EOF>>  {
  BEGIN(INITIAL);
  cool_yylval.error_msg = "EOF in string constant";
  return ERROR;
}

<INITIAL>\n { 
  curr_lineno++;
}

  /*
   * Stuff to ignore/throw-away
   */
[\f\r\v\t ]*
<COMMENT>.

<INITIAL>[.\-*/~<(){}:;,=+@] { return yytext[0]; }
<INITIAL>. {
  cool_yylval.error_msg = strdup(yytext);
  return ERROR;
}

<ERROR_TO_NEWLINE>\n      { curr_lineno++; BEGIN(INITIAL); }
<ERROR_TO_ENDQUOTE>\"     { BEGIN(INITIAL); }

<ERROR_TO_NEWLINE>[^\n]+
<ERROR_TO_ENDQUOTE>[^"]+

<ERROR_TO_ENDSTRING>\n      { BEGIN(INITIAL); }
<ERROR_TO_ENDSTRING>\"      { BEGIN(INITIAL); }
<ERROR_TO_ENDSTRING>[^\n"]

%%
