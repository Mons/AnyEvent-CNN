#!/usr/bin/env perl

use lib::abs '..';
use AnyEvent::CNN;
use EV;

my $t;$t = AE::timer 1000000,0,sub { undef $t };

my $c = AnyEvent::CNN->new(
	server    => 'jabber.ru:5222',
	timeout   => 1,
	reconnect => 1,
	debug     => 10,
);
$c->on(
	connected => sub {
		warn "connected @_";
		$c->after(1,sub {
			$c->reconnect;
		});
	},
	disconnected => sub {
		warn "discon @_";
	},
	connfail => sub {
		warn "fail @_";
	},
	error => sub {
		warn "error @_";
	},
);

$c->connect;
EV::loop;