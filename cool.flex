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
int comment_depth = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */


%}

/*
 * Define names for regular expressions here.
 */

%x COMMENT
%x STRING

DARROW          =>
ASSIGN          <-
LE              <=
DIGIT           [0-9]
ID              [a-z_][a-zA-Z0-9_]*
TYPE            [A-Z][a-zA-Z0-9_]*

%%

 /*
  *  Nested comments
  */
<INITIAL,COMMENT>"(*" {
  BEGIN(COMMENT);
  comment_depth++;
}

<COMMENT>\*\) {
  comment_depth--;
  if (comment_depth == 0)
    BEGIN(INITIAL);
  else if (comment_depth < 0)
    return (ERROR);
}

\-\-.*\n   { curr_lineno++; }

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}    { return (ASSIGN); }
{LE}        { return (LE);     }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
[Cc][Ll][Aa][Ss][Ss]                        { return (CLASS); }
[Ee][Ll][Ss][Ee]                            { return (ELSE);  }
[Ff][Ii]                                    { return (FI);    }
[Ii][Ff]                                    { return (IF);    }
[Ii][Nn]                                    { return (IN);    }
[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]            { return (INHERITS); }
[Ll][Ee][Tt]                                { return (LET);   }
[Ll][Oo][Oo][Pp]                            { return (LOOP);  }
[Pp][Oo][Oo][Ll]                            { return (POOL);  }
[Tt][Hh][Ee][Nn]                            { return (THEN);  }
[Ww][Hh][Ii][Ll][Ee]                        { return (WHILE); }
[Cc][Aa][Ss][Ee]                            { return (CASE);  }
[Ee][Ss][Aa][Cc]                            { return (ESAC);  }
[Oo][Ff]                                    { return (OF);    }
[Nn][Ee][Ww]                                { return (NEW);   }
[Ii][Ss][Vv][Oo][Ii][Dd]                    { return (ISVOID); }
[Nn][Oo][Tt]                                { return (NOT);   }

[t][Rr][Uu][Ee]     {
  cool_yylval.symbol = stringtable.add_string(yytext);
  return (BOOL_CONST);
}

[f][Aa][Ll][Ss][Ee] {
  cool_yylval.symbol = stringtable.add_string(yytext);
  return (BOOL_CONST);
}

[\-\+]?{DIGIT}+ {
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

<INITIAL>\"        BEGIN(STRING); string_buf_ptr = string_buf;
<STRING>\" {
  BEGIN(INITIAL);
  *string_buf_ptr = '\0';
  cool_yylval.symbol = stringtable.add_string(string_buf);
  return (STR_CONST);
}
<STRING>\\n        *string_buf_ptr++ = '\n';
<STRING>\\t        *string_buf_ptr++ = '\t';
<STRING>\\b        *string_buf_ptr++ = '\b';
<STRING>\\f        *string_buf_ptr++ = '\f';
<STRING>\n         ERROR;
<STRING>\\.        *string_buf_ptr++ = yytext[1];
<STRING>.          *string_buf_ptr++ = yytext[0];

<COMMENT,INITIAL>\n { 
  curr_lineno++;
}

  /*
   * Stuff to ignore/throw-away
   */
[\t ]*
<COMMENT>.

<INITIAL>[.\-*/~<(){}:;,=+] { return yytext[0]; }
<INITIAL>. {
  cool_yylval.error_msg = strdup(yytext);
  return ERROR;
}

%%
