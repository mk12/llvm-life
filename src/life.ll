;;; Copyright 2016 Mitchell Kember. Subject to the MIT License.

target triple = "x86_64-apple-macosx10.12.0"

;;; Types

%Buffer = type { i8*, i64 }

;;; Constants

@.str = private unnamed_addr constant [13 x i8] c"Hello World\0A\00"

;;; Declarations

declare i32 @puts(i8* nocapture) nounwind
declare void @exit(i32) noreturn

;;; Main

define i32 @main() {
  %1 = getelementptr [13 x i8], [13 x i8]* @.str, i64 0, i64 0
  call i32 @puts(i8* %1)
  ret i32 0
}
