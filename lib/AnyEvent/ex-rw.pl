#!/usr/bin/env perl

use lib::abs '..','../../../*/lib';
use AnyEvent::CNN::RW;
use EV;

my $t;$t = AE::timer 1000000,0,sub { undef $t };

my $c = AnyEvent::CNN::RW->new(
	server    => 'xjabber.ru:5222',
	timeout   => 1,
	reconnect => 1,
	debug     => 10,
	on_read => sub {
		my $rbuf = shift;
		warn "on_read ".$$rbuf;
	}
);
$c->on(
	connected => sub {
		warn "\tconnected @_";
		$c->{h}->push_write("<?xml?><stream:stream>");
		$c->after(10,sub {
			$c->reconnect;
		});
	},
	disconnected => sub {
		warn "\tdiscon @_";
	},
	connfail => sub {
		warn "\tfailure @_";
		shift->{host} = 'jabber.ru';
	},
	error => sub { # Need?
		warn "\terror @_";
	},
);

$c->connect;
EV::loop;