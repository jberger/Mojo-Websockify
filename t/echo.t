use Mojolicious::Lite;

use Test::More;
use Test::Mojo;

use Mojo::IOLoop;
use Mojo::Websockify;

my $id = Mojo::IOLoop->server({address => '127.0.0.1'} => sub {
  my ($loop, $tcp, $id) = @_;
  $tcp->on(read => sub {
    my ($tcp, $bytes) = @_;
    $tcp->write("got: $bytes");
  });
});
my $port = Mojo::IOLoop->acceptor($id)->port;

websocket '/socket' => sub {
  my $c = shift->render_later;
  $c->on(finish => sub { warn 'ws finished' });
  my $ws = Mojo::Websockify->new(
    tx => $c->tx,
    address => '127.0.0.1',
    port => $port,
  );
  Mojo::IOLoop->delay(
    sub { $ws->open(shift->begin) },
  )->wait;
};

my $t = Test::Mojo->new;

$t->websocket_ok('/socket')
  ->send_ok({binary => 'test123'})
  ->message_ok
  ->message_is({binary => 'got: test123'})
  ->finish_ok;

done_testing;

