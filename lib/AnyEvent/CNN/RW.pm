package AnyEvent::CNN::RW;

use parent 'AnyEvent::CNN';
use AnyEvent::RW;
use Event::Emitter;
use Scalar::Util 'weaken';

sub _on_connected_prepare {
	my ($self,$fh,$host,$port) = @_;
	#warn "success: @_";
	weaken $self;
	$self->{h} = AnyEvent::RW->new(
		fh => $self->{fh},
		debug => $self->{debug},
		#timeout => $self->{timeout},
		on_read => $self->{on_read} || sub {
			$self or return;
			$self->event(on_read => @_);
		},
		on_end => sub {
			$self or return;
			$self->disconnect(@_ ? @_ : "$!");
			$self->_reconnect_after;
		}
	);
}

1;