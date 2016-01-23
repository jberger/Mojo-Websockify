package Mojo::Websockify;

use Mojo::Base -base;

use constant DEBUG => $ENV{MOJO_WEBSOCKIFY_DEBUG} || 0;

use Mojo::IOLoop;
use Mojo::Util 'term_escape';

has ioloop => sub { Mojo::IOLoop->singleton };

has [qw/address port/];

sub open {
  my ($self, $tx, $cb) = @_;
  $cb ||= sub{};

  my %args = (
    address => $self->address,
    port    => $self->port,
  );
  my $loop = $self->ioloop;
  $loop->delay(
    sub { $loop->client(%args, shift->begin) },
    sub {
      my ($loop, $err, $tcp) = @_;

      #TODO handler $err

      $tcp->on(read => sub {
        my ($tcp, $bytes) = @_;
        warn term_escape "-- TCP >>> WebSocket ($bytes)\n" if DEBUG;
        $tx->send({binary => $bytes});
      });

      $tx->on(binary => sub {
        my ($tx, $bytes) = @_;
        warn term_escape "-- TCP <<< WebSocket ($bytes)\n" if DEBUG;
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

      $self->$cb(undef, $tcp);
    },
  )->catch(sub { $self->$cb($_[1], undef) })->wait;

  return $self;
}

1;

