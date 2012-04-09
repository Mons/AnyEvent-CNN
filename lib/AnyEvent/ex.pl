#!/usr/bin/env perl

use AnyEvent::Impl::Perl;
#use EV;

use lib::abs '..','../../../*/lib';
use AnyEvent::CNN;
use Devel::FindRef;

my $t;$t = AE::timer 1000000,0,sub { undef $t };

my $c = AnyEvent::CNN->new(
	server    => 'jabber.ru:5222',
	timeout   => 1,
	reconnect => 1,
	debug     => 10,
);
use Devel::Refcount 'refcount';
warn "created client, ref ".refcount($c);

$c->on(
	connected => sub {
		my $c = shift;
		warn "connected @_";
		warn "connected client, ref ".refcount($c);
		#Devel::FindRef::track $c;
		#$c->after(1,sub {
		#	$c->reconnect;
		#});
		#$c->after(3,sub {
			$c->disconnect;
		#});
	},
	disconnected => sub {
		#my $c = shift;
		warn "disconnected client, ref ".refcount($c);
		#undef $c;
	},
	connfail => sub {
		warn "fail @_";
	},
	error => sub {
		warn "error @_";
	},
);

warn "setup events, ref ".refcount($c);

$c->connect;
#EV::loop;
AE::cv->recv;