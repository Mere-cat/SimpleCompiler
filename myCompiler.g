grammar myCompiler;

options {
   language = Java;
}

@header {
   // import packages here.
   import java.util.HashMap;
   import java.util.ArrayList;
}

@members {
   boolean TRACEON = false;
   boolean SKIP;

   // Type information.
   public enum Type{
      INT,
      CONST_INT,
		FLOAT,
      CONST_FLOAT,
      DOUBLE,
      SHORT,
      LONG,
      VOID,
      CHAR,
      BOOL,
		ERR;
   }

   // This structure is used to record the information of a variable or a constant.
   class tVar {
      int   varIndex; // temporary variable's index. Ex: t1, t2, ..., etc.
      int   iValue;   // value of constant integer. Ex: 123.
      float fValue;   // value of constant floating point. Ex: 2.314.
   };

   class Info {
      Type theType;  // type information.
      tVar theVar;
   
      Info() {
         theType = Type.ERR;
         theVar = new tVar();
      }
   };

	
   // ============================================
   // Create a symbol table.
	// ArrayList is easy to extend to add more info. into symbol table.
	//
	// The structure of symbol table:
	// <variable ID, [Type, [varIndex or iValue, or fValue]]>
	//    - type: the variable type   (please check "enum Type")
	//    - varIndex: the variable's index, ex: t1, t2, ...
	//    - iValue: value of integer constant.
	//    - fValue: value of floating-point constant.
   // ============================================

   HashMap<String, Info> symtab = new HashMap<String, Info>();

   // labelCount is used to represent temporary label.
   // The first index is 0.
   int labelCount = 0;

   // varCount is used to represent temporary variables.
   // The first index is 0.
   int varCount = 0;

   // Record all assembly instructions.
   List<String> TextCode = new ArrayList<String>();

   /*
   * Output prologue.
   */
   void prologue()
   {
      TextCode.add("; === prologue ====");
      TextCode.add("declare dso_local i32 @printf(i8*, ...)\n");
      TextCode.add("@.strf = private unnamed_addr constant [4 x i8] c\"\%f\\0A\\00\", align 1");
      TextCode.add("@.strd = private unnamed_addr constant [4 x i8] c\"\%d\\0A\\00\", align 1");
      TextCode.add("@.str = private unnamed_addr constant [9 x i8] c\"Answer:\\0A\\00\", align 1\n");
      TextCode.add("define dso_local i32 @main()");
      TextCode.add("{");
   }
   

   /*
   * Output epilogue.
   */
   void epilogue()
   {
      /* handle epilogue */
      TextCode.add("\n; === epilogue ===");
      TextCode.add("ret i32 0");
      TextCode.add("}");
   }
   
   
   /* Generate a new label */
   String newLabel()
   {
      labelCount ++;
      return (new String("L")) + Integer.toString(labelCount);
   } 
    
    
   public List<String> getTextCode()
   {
      return TextCode;
   }
}

program: VOID_TYPE MAIN_FUNC '(' ')'
         {
            /* Output function prologue */
            prologue();
         }

        '{' 
            declarations
            statements
        '}'
         {
	         if (TRACEON)
	         System.out.println("VOID MAIN () {declarations statements}");

            /* output function epilogue */	  
            epilogue();
         };


declarations: type ID ';' declarations
{
         if (TRACEON)
            System.out.println("declarations: type ID : declarations");

         if (symtab.containsKey($ID.text)) {
            // variable re-declared.
            System.out.println("Type Error: " + 
                                 $ID.getLine() + 
                              ": Redeclared ID.");
            System.exit(0);
         }
               
         /* Add ID and its info into the symbol table. */
         Info the_entry = new Info();
         the_entry.theType = $type.attr_type;
         the_entry.theVar.varIndex = varCount;
         varCount ++;
         symtab.put($ID.text, the_entry);

         // issue the instruction.
         // Ex: \%a = alloca i32, align 4
         if ($type.attr_type == Type.INT) { 
            TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i32, align 4");
         }
         if ($type.attr_type == Type.FLOAT) { 
            TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca float, align 4");
         }
         if ($type.attr_type == Type.CHAR) { 
            TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i8, align 1");
         }
}
|
{
         if (TRACEON)
         System.out.println("declarations: ");
};


type
returns [Type attr_type]
    : INT_TYPE { if (TRACEON) System.out.println("type: INT"); $attr_type=Type.INT; }
    | CHAR_TYPE { if (TRACEON) System.out.println("type: CHAR"); $attr_type=Type.CHAR; }
    | FLOAT_TYPE {if (TRACEON) System.out.println("type: FLOAT"); $attr_type=Type.FLOAT; }
	;


statements:statement statements
         |
         ;


statement: assign_stmt ';'
         | if_stmt
         | func_no_return_stmt ';'
         | for_stmt
         | while_stmt
         | PRINTF_FUNC '(' LITERAL ',' ID ')' ';'
         {
            int vIndex = symtab.get($ID.text).theVar.varIndex;
            if (symtab.get($ID.text).theType == Type.INT) { 
               TextCode.add("\%t" + varCount + " = load i32, i32* \%t" + vIndex);
               TextCode.add("\%t" + (varCount + 1) + " = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 " + "\%t" + varCount + ")");
               varCount += 2;
            }
            if (symtab.get($ID.text).theType == Type.FLOAT) { 
               TextCode.add("\%t" + varCount + " = load float, float* \%t" + vIndex); 
			      TextCode.add("\%t" + (varCount + 1) + " = fpext float \%t" + varCount + " to double"); 
			      TextCode.add("\%t" + (varCount + 2) + " = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strf, i64 0, i64 0), double " + "\%t" + (varCount + 1) + ")");
               varCount += 3;
            }
         }
         | PRINTF_FUNC '(' LITERAL ')' ';'
         {
         	TextCode.add("\%t" + varCount + " = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str, i64 0, i64 0))");
         	varCount += 1;
         }
         ;


while_stmt: WHILE_LOOP '(' 
      {
         TextCode.add("br label \%l" + labelCount);
         TextCode.add("l" + labelCount + ":" + "\t\t\t\t;");
         labelCount++;
      }
      cond_expression 
      {
         TextCode.add("l" + (labelCount - 2) + ":" + "\t\t\t\t;");
      }
      ')' 
      block_stmt
      {
         TextCode.add("br label \%l" + (labelCount - 3));
         TextCode.add("l" + (labelCount - 1) + ":" + "\t\t\t\t;");
      }
      ;

for_stmt: FOR_LOOP '(' assign_stmt ';'
         {
            TextCode.add("br label \%l" + labelCount);
            TextCode.add("l" + labelCount + ":" + "\t\t\t\t;");
            labelCount +=2 ;              
         }
         cond_expression 
         {
            TextCode.add("l" + (labelCount - 3) + ":" + "\t\t\t\t;");
         }        
         ';' assign_stmt 
         {
            TextCode.add("br label \%l" + (labelCount - 4));
            TextCode.add("l" + (labelCount - 2) + ":" + "\t\t\t\t;");
         }
         ')' block_stmt
         {
            TextCode.add("br label \%l" + (labelCount - 3));
            TextCode.add("l" + (labelCount - 1) + ":" + "\t\t\t\t;");         
         };
		 
		 
if_stmt
   : if_then_stmt if_else_stmt
   { 
      TextCode.add("l" + labelCount + ":" + "\t\t\t\t;");
      labelCount++;
   }
   ;

	   
if_then_stmt
   : IF_COND '(' cond_expression ')' 
   {
      TextCode.add("l" + (labelCount - 2) + ":" + "\t\t\t\t;");
   }
   block_stmt
   {
      TextCode.add("br label " + "\%l" + labelCount);
   }
   ;


if_else_stmt
   : ELSE_COND
   {
      TextCode.add("l" + (labelCount - 1) + ":" + "\t\t\t\t;");
   }
      block_stmt
   {
      TextCode.add("br label " + "\%l" + labelCount);
   }
   |          
   {
         TextCode.add("l" + (labelCount - 1) + ":" + "\t\t\t\t;");
         TextCode.add("br label " + "\%l" + labelCount);
   };

				  
block_stmt: '{' statements '}'
	  ;


assign_stmt: ID '=' arith_expression
            {
               Info theRHS = $arith_expression.theInfo;
		         Info theLHS = symtab.get($ID.text);
               
               // int type
               if ((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {		   
                  TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex);
               }
               else if ((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                  TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex);				
				   }

               // float type
               else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {		   
                  TextCode.add("store float \%t" + theRHS.theVar.varIndex + ", float* \%t" + theLHS.theVar.varIndex);
               }
               else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                  TextCode.add("store float " + theRHS.theVar.iValue + ", float* \%t" + theLHS.theVar.varIndex);				
				   }

               // // char type
               // else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {		   
               //    TextCode.add("store float \%t" + theRHS.theVar.varIndex + ", float* \%t" + theLHS.theVar.varIndex);
               // }
               // else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
               //    TextCode.add("store float " + theRHS.theVar.iValue + ", float* \%t" + theLHS.theVar.varIndex);				
				   // }
};

arith_expression
returns [Info theInfo]
@init {theInfo = new Info();}
               : a=multExpr { $theInfo=$a.theInfo; }( 
                  // Addition
                  '+' b=multExpr
                    {
                       // int type			   
                        if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                              TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        } 
                        else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                              TextCode.add("\%t" + varCount + " = add nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                              TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.CONST_INT;					            
                              $theInfo.theVar.iValue = $a.theInfo.theVar.iValue + $b.theInfo.theVar.iValue;					           
                        }

                        // float type
                        else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fadd float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        } 
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fadd double " + $a.theInfo.theVar.fValue + ", " + "\%t" + (varCount - 1) );
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fadd double \%t" + (varCount - 1) + ", " + $b.theInfo.theVar.fValue);
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.CONST_FLOAT;					            
                              $theInfo.theVar.fValue = $a.theInfo.theVar.fValue + $b.theInfo.theVar.fValue;					           
                        }
                     }
                  // Subtraction
                  | '-' c=multExpr
                  {
                        // int type
                        if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                              TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        } 
                        else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                              TextCode.add("\%t" + varCount + " = sub nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                              TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.INT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.CONST_INT;					           
                              $theInfo.theVar.iValue = $a.theInfo.theVar.iValue - $c.theInfo.theVar.iValue;					            
                        }

                        // float type
                        else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fsub float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                     
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        } 
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fsub double " + $a.theInfo.theVar.fValue + ", " + "\%t" + (varCount - 1) );
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                              TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fsub double \%t" + (varCount - 1) + ", " + $c.theInfo.theVar.fValue);
                              varCount++;
                              TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.FLOAT;
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                        }
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                              // Update arith_expression's theInfo.
                              $theInfo.theType = Type.CONST_FLOAT;					            
                              $theInfo.theVar.fValue = $a.theInfo.theVar.fValue - $c.theInfo.theVar.fValue;					           
                        }
                  }
)*;

multExpr
returns [Info theInfo]
@init {theInfo = new Info();}
         : a=signExpr { $theInfo=$a.theInfo; }(
         // Multiplication
          '*' b=signExpr
         {
            // int type
            if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                  TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            } 
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                  TextCode.add("\%t" + varCount + " = mul nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                  TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.CONST_INT;
                  $theInfo.theVar.iValue = $a.theInfo.theVar.iValue * $b.theInfo.theVar.iValue;
            }

            // float type
            else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fmul float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            } 
            else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fmul double " + $a.theInfo.theVar.fValue + ", " + "\%t" + (varCount - 1) );
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fmul double \%t" + (varCount - 1) + ", " + $b.theInfo.theVar.fValue);
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.CONST_FLOAT;
                  $theInfo.theVar.fValue = $a.theInfo.theVar.fValue * $b.theInfo.theVar.fValue;
            }
         }
         // Division              
         | '/' c=signExpr
         {
            // int type
            if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                  TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            } 
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                  TextCode.add("\%t" + varCount + " = sdiv i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
               
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                  TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
            
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.INT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.CONST_INT;
                  $theInfo.theVar.iValue = $a.theInfo.theVar.iValue / $c.theInfo.theVar.iValue;
            }

            // float type
            else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fdiv float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
            
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            } 
            else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fdiv double " + $a.theInfo.theVar.fValue + ", " + "\%t" + (varCount - 1) );
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                  TextCode.add("\%t" + varCount + " = fpext float \%t" + (varCount - 1) + " to double");
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fdiv double \%t" + (varCount - 1) + ", " + $c.theInfo.theVar.fValue);
                  varCount++;
                  TextCode.add("\%t" + varCount + " = fptrunc double \%t" + (varCount - 1) + " to float");
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.FLOAT;
                  $theInfo.theVar.varIndex = varCount;
                  varCount ++;
            }
            else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                  // Update arith_expression's theInfo.
                  $theInfo.theType = Type.CONST_FLOAT;
                  $theInfo.theVar.fValue = $a.theInfo.theVar.fValue / $b.theInfo.theVar.fValue;
            }
         }
	  )*
	;

signExpr
returns [Info theInfo]
@init {theInfo = new Info();}
        : a=primaryExpr { $theInfo=$a.theInfo; }
        | '-' b=primaryExpr
	;
		  
primaryExpr
returns [Info theInfo]
@init {theInfo = new Info();}
         : DEC_NUM
	      {
            $theInfo.theType = Type.CONST_INT;
			   $theInfo.theVar.iValue = Integer.parseInt($DEC_NUM.text);
         }
         | FLOAT_NUM
         | ID
              {
               // get type information from symtab.
               Type the_type = symtab.get($ID.text).theType;
				   $theInfo.theType = the_type;

               // get variable index from symtab.
               int vIndex = symtab.get($ID.text).theVar.varIndex;
				
               switch (the_type) {
                  case INT: 
                     // get a new temporary variable and
                     // load the variable into the temporary variable.
                           
                     // Ex: \%tx = load i32, i32* \%ty.
                     TextCode.add("\%t" + varCount + "=load i32, i32* \%t" + vIndex);
                        
                     // Now, ID's value is at the temporary variable \%t[varCount].
                     // Therefore, update it.
                     $theInfo.theVar.varIndex = varCount;
                     varCount ++;
                     break;
                  
                  case FLOAT:
                     TextCode.add("\%t" + varCount + "=load float, float* \%t" + vIndex);
                     $theInfo.theVar.varIndex = varCount;
                     varCount ++;
                     break;
                  case CHAR:
                     TextCode.add("\%t" + varCount + "=load i8, i8* \%t" + vIndex);
                     $theInfo.theVar.varIndex = varCount;
                     varCount ++;
                     break;
               }
              }
	   | '&' ID
	   | '(' a=arith_expression ')'
      { 
         if($a.theInfo.theType == Type.INT) {
            $theInfo.theType = Type.INT;
         }
         else if($a.theInfo.theType == Type.FLOAT){
            $theInfo.theType = Type.FLOAT;
         }
         else if($a.theInfo.theType == Type.CONST_INT){
            $theInfo.theType = Type.CONST_INT;
            $theInfo.theVar.iValue = $a.theInfo.theVar.iValue;
         }
         else if($a.theInfo.theType == Type.CONST_FLOAT){
            $theInfo.theType = Type.CONST_FLOAT;
            $theInfo.theVar.fValue = $a.theInfo.theVar.fValue;
         }
      }
;

		   
func_no_return_stmt: ID '(' argument ')'
                   ;


argument: arg (',' arg)*
        ;

arg: arith_expression
   | LITERAL
   ;
		   
cond_expression: a=arith_expression 
                 (  EQ_OP b=arith_expression 
                  {  
                     Info theRHS = $b.theInfo;
                     Info theLHS = $a.theInfo; 
                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp eq i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp eq i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float type
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oeq float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oeq float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oeq float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp oeq float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
                  | NE_OP c=arith_expression
                  {  
                     Info theRHS = $c.theInfo;
                     Info theLHS = $a.theInfo; 
                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp ne i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp ne i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float type
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp one float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp one float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp one float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp one float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
                  | GREATER_OP d=arith_expression
                  {  
                     Info theRHS = $d.theInfo;
                     Info theLHS = $a.theInfo; 
                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sgt i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp sgt i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ogt float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ogt float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ogt float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp ogt float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
                  | GE_OP e=arith_expression
                  {  
                     Info theRHS = $e.theInfo;
                     Info theLHS = $a.theInfo;
                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sge i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp sge i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float type
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oge float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oge float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp oge float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp oge float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
                  | LESS_OP f=arith_expression
                  {  
                     Info theRHS = $f.theInfo;
                     Info theLHS = $a.theInfo; 
                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp slt i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp slt i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float type
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp olt float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp olt float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp olt float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp olt float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
                  | LE_OP g=arith_expression
                  {  
                     Info theRHS = $g.theInfo;
                     Info theLHS = $a.theInfo; 

                     // int type
                     if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + (varCount - 1) + ", " + theRHS.theVar.iValue);
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                     TextCode.add("\%t" + varCount + " = icmp sle i32 " + theLHS.theVar.iValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                     TextCode.add("\%t" + varCount + " = icmp sle i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                     }

                     // float type
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ole float \%t" + (varCount - 2) + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ole float \%t" + (varCount - 1) + ", " + theRHS.theVar.fValue);
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.FLOAT)) {
                     TextCode.add("\%t" + varCount + " = fcmp ole float " + theLHS.theVar.fValue + ", \%t" + (varCount - 1));
                     }
                     else if((theLHS.theType == Type.CONST_FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) { 
                     TextCode.add("\%t" + varCount + " = fcmp ole float " + theLHS.theVar.fValue + ", " + theRHS.theVar.fValue);
                     }
                     TextCode.add("br i1 \%t" + varCount + ", label \%l" + labelCount + ", label \%l" + (labelCount + 1));
                     varCount++;
                     labelCount+=2;
                  } 
)*;

		   
/* description of the tokens */
/*----------------------*/
/*   Reserved Keywords  */
/*----------------------*/
// Conditions
SWITCH_COND: 'switch';
CASE_COND: 'case';
DEFAULT_COND: 'default';
IF_COND: 'if';
ELSE_COND: 'else';

// Loops
FOR_LOOP: 'for';
WHILE_LOOP: 'while';
DO_LOOP: 'do';
BREAK_: 'break';
CONTINUE_: 'continue';

// Data types
INT_TYPE  : 'int';
CHAR_TYPE : 'char';
BOOL_TYPE : 'bool';
FLOAT_TYPE: 'float';
DOUBLE_TYPE: 'double';
SHORT_TYPE: 'short';
LONG_TYPE: 'long';
VOID_TYPE : 'void';
CONST_TYPE: 'const';
STRUCT_TYPE: 'struct';

// Other keywords
INCLUDE_: 'include';
AUTO_: 'auto';
ENUM_: 'enum';
EXTERN_: 'extern';
GOTO_: 'goto';
INLINE_: 'inline';
REG_: 'register';
RESTRICT_: 'restrict';
RETURN_: 'return';
SIGNED_: 'signed';
SIZEOF_: 'sizeof';
STATIC_: 'static';
TYPEDEF_: 'typedef';
UNION_: 'union';
UNSIGNED_: 'unsigned';
VOLATILE_: 'volatile';

/*----------------------*/
/* Special String/Char  */
/*----------------------*/
// File Names
HEADER_FILE: '#include <' (options{greedy=false;}: ID)* '.h>';

// Functions
MAIN_FUNC: 'main';
PRINTF_FUNC: 'printf';

// Literal
LITERAL: '"' (options{greedy=false;}: .)* '"';

// Char (content itself)
CHAR: '\'' (options{greedy=false;}: .)? '\'';

/*----------------------*/
/*   Special Symbol     */
/*----------------------*/
WS:( ' ' | '\t' | '\r' | '\n' ) {$channel=HIDDEN;};

// Punctuation mark
DOUBLE_QUOTE: '"';
SINGLE_QUOTE: '\'';
SEMICOLON: ';';
COMMA: ',';
COLON: ':';
PRE_PROCESSOR: '#'; 
PERIOD: '.';
LEFT_BRACKET: '['; 
RIGHT_BRACKET: ']';
LEFT_PAREM: '(';
RIGHT_PAREM: ')'; 
LEFT_BRACE: '{';
RIGHT_BRACE: '}';

// Logic Operators
BITAND_OP: '&';
BITOR_OP: '|';
AND_OP: '&&';
OR_OP: '||';
NOT_OP: '!';

// Math Operators
MOD_OP: '%';
DIV_OP: '/';
MULT_OP: '*';
PLUS_OP: '+';
MINUS_OP: '-';
COMPL_OP: '~';
ASSIGN_OP: '=';
LESS_OP: '<';
GREATER_OP: '>';

/*----------------------*/
/*  Compound Operators  */
/*----------------------*/
EQ_OP : '==';
LE_OP : '<=';
GE_OP : '>=';
NE_OP : '!=';
PP_OP : '++';
MM_OP : '--'; 
RSHIFT_OP : '<<';
LSHIFT_OP : '>>';
AA_OP : '+=';
SA_OP : '-=';
MULA_OP : '*=';
DA_OP : '/=';
MODA_OP: '%=';

DEC_NUM : ('0' | ('1'..'9')(DIGIT)*);

ID : (LETTER)(LETTER | DIGIT)*;

FLOAT_NUM: FLOAT_NUM1 | FLOAT_NUM2 | FLOAT_NUM3;
fragment FLOAT_NUM1: (DIGIT)+'.'(DIGIT)*;
fragment FLOAT_NUM2: '.'(DIGIT)+;
fragment FLOAT_NUM3: (DIGIT)+;

/* Comments */
COMMENT: (COMMENT1 | COMMENT2) {$channel=HIDDEN;};
fragment COMMENT1 : '//'(.)*'\n';
fragment COMMENT2 : '/*' (options{greedy=false;}: .)* '*/';

fragment LETTER : 'a'..'z' | 'A'..'Z' | '_';
fragment DIGIT : '0'..'9';
