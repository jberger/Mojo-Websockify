use Mojolicious::Lite;

use Mojo::IOLoop;
use Mojo::Websockify;

websocket '/proxy' => sub {
  my $c = shift;
  $c->render_later->on(finish => sub { warn 'websocket closing' });

  my $tx = $c->tx;
  $tx->with_protocols('binary');

  my $host = $c->param('target') || '127.0.0.1';
  my $port = $host =~ s/:(\d+)$// ? $1 : 5901;

  my $ws = Mojo::Websockify->new(address => $host, port => $port);
  $ws->on(error => sub { $tx->finish(4500, $_[1]) });
  $ws->open($tx);
};

get '/*target' => sub {
  my $c = shift;
  my $target = $c->stash('target');
  my $url = $c->url_for('proxy')->query(target => $target);
  $url->path->leading_slash(0); # novnc assumes no leading slash :(
  $c->render(
    vnc  =>
    base => $c->tx->req->url->to_abs,
    path => $url,
  );
};

app->start;

