  $ ./server.exe &
  wait_call succeeded
  method:hello
  host:localhost
  caml-grcp:hello
  user-agent:grpc-c/10.0.0 (linux; chttp2)
  wait_call 2 succeeded
  msg: Are you happy?
  wait_call 3 succeeded

  $ sleep 1

  $ ./client.exe &
  wait_call succeeded
  caml-grcp:bye
  wait_call 2 succeeded
  msg: Yes, I feel very connected
  I'm happy that you said "Hi!"

  $ wait
