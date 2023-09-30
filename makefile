all: genToken genjavaFile

genToken:
	java -cp antlr-3.5.3-complete-no-st3.jar org.antlr.Tool myCompiler.g

genjavaFile:
	javac -cp antlr-3.5.3-complete-no-st3.jar: *.java

run:
	java -cp antlr-3.5.3-complete-no-st3.jar:. myCompiler_test $(TARGET) > mytest.ll
	lli mytest.ll

run1:
	java -cp antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test_program/test1.c > test1.ll
	lli test1.ll

run2:
	java -cp antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test_program/test2.c > test2.ll
	lli test2.ll

run3:
	java -cp antlr-3.5.3-complete-no-st3.jar:. myCompiler_test test_program/test3.c > test3.ll
	lli test3.ll
	
clean:
	-rm *.class
	-rm *.tokens
	-rm myCompilerLexer.java
	-rm myCompilerParser.java
	-rm -rf .antlr
	-rm *.ll
