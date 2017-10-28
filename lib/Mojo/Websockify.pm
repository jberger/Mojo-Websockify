package Mojo::Websockify;

use Mojo::Base 'Mojo::EventEmitter';

use constant DEBUG => $ENV{MOJO_WEBSOCKIFY_DEBUG} || 0;

use Mojo::IOLoop;
use Mojo::Util 'term_escape';

has ioloop => sub { Mojo::IOLoop->singleton };

has [qw/address port/];

sub open {
  my ($self, $tx, $cb) = @_;

  my %args = (
    address => $self->address,
    port    => $self->port,
  );
  my $loop = $self->ioloop;
  $loop->delay(
    sub { $loop->client(%args, shift->begin) },
    sub {
      my ($loop, $err, $tcp) = @_;

      $self->emit(error => "TCP connection error: $err") if $err;
      $tcp->on(error => sub { $self->emit(error => "TCP error: $_[1]") });

      my $pause = do {
        my $ws_stream = Mojo::IOLoop->stream($c->tx->connection);
        my $unpause = sub { $tcp->start; $ws_stream->start };
        $ws_stream->on(drain => $unpause);
        $tcp->on(drain => $unpause);
        sub { $tcp->stop; $ws_stream->stop };
      };

      $tcp->on(read => sub {
        my ($tcp, $bytes) = @_;
        warn term_escape "-- TCP >>> WebSocket ($bytes)\n" if DEBUG;
        $pause->();
        $tx->send({binary => $bytes});
      });

      $tx->on(binary => sub {
        my ($tx, $bytes) = @_;
        warn term_escape "-- TCP <<< WebSocket ($bytes)\n" if DEBUG;
        $pause->();
        $tcp->write($bytes);
      });

      $tx->on(finish => sub {
        my (undef, $code, $reason) = @_;
        $reason ||= '';
        warn term_escape "-- Websocket Connection closed. Code: $code ($reason)\n" if DEBUG;
        $tcp->close;
        undef $tcp;
        undef $tx;
      });

      $self->$cb(undef, $tcp) if $cb;
    },
  )->tap(on => error => sub { $self->$cb($_[1], undef) })->wait;

  return $self;
}

1;

