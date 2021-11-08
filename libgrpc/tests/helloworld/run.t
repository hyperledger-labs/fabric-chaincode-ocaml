  $ ./server.exe &
  wait_call succeeded
  caml-grcp:hello
  user-agent:grpc-c/10.0.0 (linux; chttp2)
  wait_call 2 succeeded
  msg: Are you happy?

  $ sleep 1

  $ ./client.exe &
  wait_call succeeded
  caml-grcp:bye

  $ wait
