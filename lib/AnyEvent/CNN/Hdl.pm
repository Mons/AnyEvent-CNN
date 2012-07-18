package AnyEvent::CNN::Hdl;

use parent 'AnyEvent::CNN';
use AnyEvent::Handle;
use Event::Emitter;
use Scalar::Util 'weaken';

sub _on_connected_prepare {
	my ($self,$fh,$host,$port) = @_;
	#warn "success: @_";
	weaken $self;
	$self->{h} = AnyEvent::Handle->new(
		fh    => $self->{fh},
		timeout => $self->{timeout},
		on_read => $self->{on_read} || sub {
			$self or return;
			$self->event(on_read => @_);
		},
		on_eof => sub {
			$self or return;
			$self->disconnect(@_ ? @_ : "EOF");
			$self->_reconnect_after;
		},
		on_error => sub {
			$self or return;
			$self->disconnect(@_ ? @_ : "$!");
			$self->_reconnect_after;
		}
	);
}

1;