;;; Copyright 2016 Mitchell Kember. Subject to the MIT License.

target triple = "x86_64-apple-macosx10.12.0"

;;; Types

%FILE = type opaque

%Buffer = type {
  i8*, ; Array
  i32  ; Length
}

%Grid = type {
  i8*, ; Primary array
  i8*, ; Auxiliary array
  i32, ; Array length
  i32, ; Grid width
  i32  ; Grid height
}

;;; Constants

@.read_mode = private unnamed_addr constant [2 x i8] c"r\00"
@.print_fmt = private unnamed_addr constant [12 x i8] c"\1B[2J\1B[H%.*s\00"
@.open_alt = private unnamed_addr constant [9 x i8] c"\1B[?1049h\00"
@.close_alt = private unnamed_addr constant [9 x i8] c"\1B[?1049l\00"

;;; Globals

@keep_running = private global i1 true

;;; Declarations

declare void (i32)* @signal(i32, void (i32)*)

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

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8* readonly, i64, i32, i1)

;;; Main

define i32 @main(i32 %argc, i8** readonly %argv) {
entry:
  %g = alloca %Grid
  %right = icmp eq i32 %argc, 3
  br i1 %right, label %body.0, label %error

body.0:
  call void (i32)* @signal(i32 2, void (i32)* @handle_sigint)
  %ptr1 = getelementptr inbounds i8*, i8** %argv, i64 1
  %ptr2 = getelementptr inbounds i8*, i8** %argv, i64 2
  %name = load i8*, i8** %ptr1
  %arg2 = load i8*, i8** %ptr2
  %millis = call i32 @atol(i8* %arg2)
  %micros = mul i32 %millis, 1000
  %buffer = call %Buffer @read_file(i8* %name)
  %grid = call %Grid @parse_grid(%Buffer %buffer)
  store %Grid %grid, %Grid* %g
  %open_alt = getelementptr [9 x i8], [9 x i8]* @.open_alt, i64 0, i64 0
  call i32 (i8*, ...) @printf(i8* %open_alt)
  br label %body.1

body.1:
  call void @print_grid(%Grid* %g)
  call void @update_grid(%Grid* %g)
  call i32 @"\01_usleep"(i32 %micros)
  %keep_running = load volatile i1, i1* @keep_running
  br i1 %keep_running, label %body.1, label %finish

error:
  ret i32 1

finish:
  %close_alt = getelementptr [9 x i8], [9 x i8]* @.close_alt, i64 0, i64 0
  call i32 (i8*, ...) @printf(i8* %close_alt)
  ret i32 0
}

;;; SIGINT handler

define private void @handle_sigint(i32) {
entry:
  store volatile i1 0, i1* @keep_running
  ret void
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
  %primary = extractvalue %Buffer %buf, 0
  %size = extractvalue %Buffer %buf, 1
  %s64 = zext i32 %size to i64
  %aux = call i8* @malloc(i64 %s64)
  call void @llvm.memcpy.p0i8.p0i8.i64(
      i8* %aux, i8* %primary, i64 %s64, i32 1, i1 0)
  %res.0 = insertvalue %Grid undef, i8* %primary, 0
  %res.1 = insertvalue %Grid %res.0, i8* %aux, 1
  %res.2 = insertvalue %Grid %res.1, i32 %size, 2
  %res.3 = insertvalue %Grid %res.2, i32 %width, 3
  %res.4 = insertvalue %Grid %res.3, i32 %height, 4
  ret %Grid %res.4
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

; Computes the next generation and writes it into the auxiliary array.
define private void @update_grid(%Grid* %g) {
entry:
  %width.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 3
  %height.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 4
  %width = load i32, i32* %width.ptr
  %height = load i32, i32* %height.ptr
  br label %body.0

body.0:
  %i = phi i32 [ 0, %entry ], [ %i.0, %body.1 ]
  %cond.i = icmp slt i32 %i, %height
  br i1 %cond.i, label %body.1, label %body.3

body.1:
  %j = phi i32 [ 0, %body.0 ], [ %j.0, %body.2 ]
  %cond.j = icmp slt i32 %j, %width
  %i.0 = add i32 %i, 1
  br i1 %cond.j, label %body.2, label %body.0

body.2:
  call void @update_cell(%Grid* %g, i32 %i, i32 %j)
  %j.0 = add i32 %j, 1
  br label %body.1

body.3:
  %primary.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 0
  %aux.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 1
  %primary = load i8*, i8** %primary.ptr
  %aux = load i8*, i8** %aux.ptr
  store i8* %aux, i8** %primary.ptr
  store i8* %primary, i8** %aux.ptr
  ret void
}

; Updates a single cell at location (i,j).
define private void @update_cell(%Grid* %g, i32 %i, i32 %j) {
entry:
  %index = call i32 @coord_to_index(%Grid* %g, i32 %i, i32 %j)
  %neighbours = call i32 @live_neighbours(%Grid* %g, i32 %i, i32 %j)
  %two = icmp eq i32 %neighbours, 2
  %three = icmp eq i32 %neighbours, 3
  %either = select i1 %two, i1 true, i1 %three
  %live = call i32 @cell_is_alive(%Grid* %g, i32 %i, i32 %j)
  %is_live = icmp eq i32 %live, 1
  %next = select i1 %is_live, i1 %either, i1 %three
  %aux.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 1
  %aux = load i8*, i8** %aux.ptr
  %ptr = getelementptr i8, i8* %aux, i32 %index
  %char = select i1 %next, i8 88, i8 46
  store i8 %char, i8* %ptr
  ret void
}

; Returns the number of live neighbours that the cell at (i,j) has.
define private i32 @live_neighbours(%Grid* readonly %g, i32 %i, i32 %j) {
entry:
  %im1 = sub i32 %i, 1
  %ip1 = add i32 %i, 1
  %jm1 = sub i32 %j, 1
  %jp1 = add i32 %j, 1
  %n0 = call i32 @cell_is_alive(%Grid* %g, i32 %im1, i32 %jm1)
  %n1 = call i32 @cell_is_alive(%Grid* %g, i32 %im1, i32 %j)
  %n2 = call i32 @cell_is_alive(%Grid* %g, i32 %im1, i32 %jp1)
  %n3 = call i32 @cell_is_alive(%Grid* %g, i32 %i, i32 %jm1)
  %n4 = call i32 @cell_is_alive(%Grid* %g, i32 %i, i32 %jp1)
  %n5 = call i32 @cell_is_alive(%Grid* %g, i32 %ip1, i32 %jm1)
  %n6 = call i32 @cell_is_alive(%Grid* %g, i32 %ip1, i32 %j)
  %n7 = call i32 @cell_is_alive(%Grid* %g, i32 %ip1, i32 %jp1)
  %res.0 = add i32 %n0, %n1
  %res.1 = add i32 %res.0, %n2
  %res.2 = add i32 %res.1, %n3
  %res.3 = add i32 %res.2, %n4
  %res.4 = add i32 %res.3, %n5
  %res.5 = add i32 %res.4, %n6
  %res.6 = add i32 %res.5, %n7
  ret i32 %res.6
}

; Returns true if the cell at (i,j) is alive in the primary array.
define private i32 @cell_is_alive(%Grid* readonly %g, i32 %i, i32 %j) {
entry:
  %width.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 3
  %height.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 4
  %width = load i32, i32* %width.ptr
  %height = load i32, i32* %height.ptr
  %cond.il = icmp eq i32 %i, -1
  %cond.ih = icmp eq i32 %i, %height
  %cond.jl = icmp eq i32 %j, -1
  %cond.jh = icmp eq i32 %j, %width
  %outside.0 = select i1 %cond.il, i1 true, i1 %cond.ih
  %outside.1 = select i1 %outside.0, i1 true, i1 %cond.jl
  %outside.2 = select i1 %outside.1, i1 true, i1 %cond.jh
  br i1 %outside.2, label %body.2, label %body.1

body.1:
  %index = call i32 @coord_to_index(%Grid* %g, i32 %i, i32 %j)
  %primary.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 0
  %primary = load i8*, i8** %primary.ptr
  %ptr = getelementptr i8, i8* %primary, i32 %index
  %char = load i8, i8* %ptr
  %cond = icmp eq i8 %char, 88
  %res = select i1 %cond, i32 1, i32 0
  ret i32 %res

body.2:
  ret i32 0
}

; Converts a coordinate pair to an index into the array. Must be in range.
define private i32 @coord_to_index(%Grid* readonly %g, i32 %i, i32 %j) {
entry:
  %width.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 3
  %width = load i32, i32* %width.ptr
  %wp1 = add i32 %width, 1
  %res.0 = mul i32 %i, %wp1
  %res.1 = add i32 %res.0, %j
  ret i32 %res.1
}

;;; Print grid

define private void @print_grid(%Grid* readonly %g) {
entry:
  %fmt = getelementptr [12 x i8], [12 x i8]* @.print_fmt, i64 0, i64 0
  %start.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 0
  %size.ptr = getelementptr %Grid, %Grid* %g, i64 0, i32 2
  %start = load i8*, i8** %start.ptr
  %size = load i32, i32* %size.ptr
  call i32 (i8*, ...) @printf(i8* %fmt, i32 %size, i8* %start)
  ret void
}
