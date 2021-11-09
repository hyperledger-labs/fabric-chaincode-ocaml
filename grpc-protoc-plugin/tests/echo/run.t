  $ ./server.exe &
  /grpc.examples.echo.Echo/UnaryEcho
  /grpc.examples.echo.Echo/ClientStreamingEcho
  /grpc.examples.echo.Echo/ServerStreamingEcho
  /grpc.examples.echo.Echo/BidirectionalStreamingEcho

  $ ./client.exe &
  Unary
  Client
  Client Stream
  ClientCustomerMe
  Server Stream
  C
  l
  i
  e
  n
  t
  Bidirectional
  Client
  Customer
  Me

  $ wait
