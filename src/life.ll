;;; Copyright 2016 Mitchell Kember. Subject to the MIT License.

target triple = "x86_64-apple-macosx10.12.0"

;;; Types

%FILE = type opaque

%Buffer = type {
  i8*, ; Array
  i32  ; Length
}

%Grid = type {
  %Buffer, ; Printable buffer
  i32,     ; Width
  i32      ; Height
}

;;; Constants

@.read_mode = private unnamed_addr constant [2 x i8] c"r\00"
@.print_fmt = private unnamed_addr constant [12 x i8] c"\1B[2J\1B[H%.*s\00"

;;; Declarations

declare i32 @printf(i8* readonly, ...)
declare void @exit(i32) noreturn

declare i8* @malloc(i64)
declare void @free(i8*)

declare i32 @"\01_usleep"(i32)

declare %FILE* @"\01_fopen"(i8* readonly, i8* readonly)
declare i32 @fseek(%FILE*, i64, i32)
declare i64 @ftell(%FILE*)
declare i64 @fread(i8*, i64, i64, %FILE*)
declare i32 @fclose(%FILE*)

;;; Main

define i32 @main(i32 %argc, i8** readonly %argv) {
entry:
  %right = icmp eq i32 %argc, 3
  br i1 %right, label %body.0, label %error

body.0:
  %ptr1 = getelementptr inbounds i8*, i8** %argv, i64 1
  %ptr2 = getelementptr inbounds i8*, i8** %argv, i64 2
  %name = load i8*, i8** %ptr1
  %arg2 = load i8*, i8** %ptr2
  %millis = call i32 @atol(i8* %arg2)
  %micros = mul i32 %millis, 1000
  %buffer = call %Buffer @read_file(i8* %name)
  %grid = call %Grid @parse_grid(%Buffer %buffer)
  br label %body.1

body.1:
  call void @print_grid(%Grid %grid)
  call void @update_grid(%Grid %grid)
  call i32 @"\01_usleep"(i32 %micros)
  br label %body.1

error:
  ret i32 1
}

;;; Parse integer

define private i32 @atol(i8* readonly %str) {
entry:
  br label %body.0

body.0:
  %res = phi i32 [ 0, %entry ], [ %res.0, %body.1 ]
  %ptr = phi i8* [ %str, %entry ], [ %ptr.0, %body.1 ]
  %char = load i8, i8* %ptr, align 1
  %0 = icmp eq i8 %char, 0
  br i1 %0, label %body.2, label %body.1

body.1:
  %1 = sext i8 %char to i32
  %2 = sub i32 %1, 48
  %3 = mul i32 %res, 10
  %res.0 = add i32 %2, %3
  %ptr.0 = getelementptr inbounds i8, i8* %ptr, i32 1
  br label %body.0

body.2:
  ret i32 %res.0
}

;;; Read file

; Opens the file named %name and reads its entire contents into a buffer. Exits
; with exit status 1 if the file cannot be opened.
define private %Buffer @read_file(i8* readonly %name) {
entry:
  %mode = getelementptr [2 x i8], [2 x i8]* @.read_mode, i64 0, i64 0
  %file = call %FILE* @"\01_fopen"(i8* %name, i8* %mode)
  %null = icmp eq %FILE* %file, null
  br i1 %null, label %error, label %cont

error:
  call void @exit(i32 1)
  unreachable

cont:
  call i32 @fseek(%FILE* %file, i64 0, i32 2)
  %size = call i64 @ftell(%FILE* %file)
  %buf = call i8* @malloc(i64 %size)
  call i32 @fseek(%FILE* %file, i64 0, i32 0)
  call i64 @fread(i8* %buf, i64 1, i64 %size, %FILE* %file)
  call i32 @fclose(%FILE* %file)
  %size.32 = trunc i64 %size to i32
  %res.0 = insertvalue %Buffer undef, i8* %buf, 0
  %res.1 = insertvalue %Buffer %res.0, i32 %size.32, 1
  ret %Buffer %res.1
}

;;; Parse grid

; Parses a Buffer as a Grid.
define private %Grid @parse_grid(%Buffer %buf) {
entry:
  %width = call i32 @first_line_length(%Buffer %buf)
  %height = call i32 @number_of_lines(%Buffer %buf)
  %res.0 = insertvalue %Grid undef, %Buffer %buf, 0
  %res.1 = insertvalue %Grid %res.0, i32 %width, 1
  %res.2 = insertvalue %Grid %res.1, i32 %height, 2
  ret %Grid %res.2
}

; Returns the length of the first line in %buf.
define private i32 @first_line_length(%Buffer %buf) {
entry:
  %start = extractvalue %Buffer %buf, 0
  br label %body.0

body.0:
  %i = phi i32 [ 0, %entry ], [ %i.0, %body.0 ]
  %ptr = getelementptr inbounds i8, i8* %start, i32 %i
  %char = load i8, i8* %ptr
  %cond = icmp eq i8 %char, 10
  %i.0 = add i32 %i, 1
  br i1 %cond, label %body.1, label %body.0

body.1:
  ret i32 %i
}

; Returns the number of lines in %buf.
define private i32 @number_of_lines(%Buffer %buf) {
entry:
  %start = extractvalue %Buffer %buf, 0
  %length = extractvalue %Buffer %buf, 1
  %lenm1 = sub i32 %length, 1
  br label %body.0

body.0:
  %i = phi i32 [ 0, %entry ], [ %i.0, %body.1 ]
  %lines = phi i32 [ 1, %entry ], [ %lines.0, %body.1 ]
  %cond = icmp slt i32 %i, %lenm1
  br i1 %cond, label %body.1, label %body.2

body.1:
  %ptr = getelementptr inbounds i8, i8* %start, i32 %i
  %char = load i8, i8* %ptr
  %newline = icmp eq i8 %char, 10
  %inc = add i32 %lines, 1
  %lines.0 = select i1 %newline, i32 %inc, i32 %lines
  %i.0 = add i32 %i, 1
  br label %body.0

body.2:
  ret i32 %lines
}

;;; Update grid

define private void @update_grid(%Grid %g) {
entry:
  ret void
}

;;; Print grid

define private void @print_grid(%Grid %g) {
entry:
  %fmt = getelementptr [12 x i8], [12 x i8]* @.print_fmt, i64 0, i64 0
  %buffer = extractvalue %Grid %g, 0
  %start = extractvalue %Buffer %buffer, 0
  %length = extractvalue %Buffer %buffer, 1
  call i32 (i8*, ...) @printf(i8* %fmt, i32 %length, i8* %start)
  ret void
}
