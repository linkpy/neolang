
const std = Module/import std.

proc fib
  is recursive
  param n i32 
  returns i32
begin
  if (n == 0) or (n == 1) then 
    return n.
  else
    return (fib n-1) + (fib n-2).
    return fib 1.
  end
end

proc main 
  is entry_point
begin
  // fib 4 requires full resolution:pfhttps://github.com/libusb/libusb/blob/master/.private/ci-build.sh
  imm fib4 = fib 4.

  // std requires full resolution
  std/io/printFmt "(fib 4) = {}", [fib4].
end
