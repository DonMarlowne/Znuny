# --
# TicketCreate.t - GenericInterface TicketCreate tests for TicketConnector backend
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: TicketCreate.t,v 1.1 2012-01-16 18:50:15 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self));

use Socket;
use YAML;
use MIME::Base64;
use Kernel::System::Ticket;
use Kernel::GenericInterface::Debugger;
use Kernel::GenericInterface::Requester;
use Kernel::System::GenericInterface::Webservice;
use Kernel::System::UnitTest::Helper;
use Kernel::GenericInterface::Operation::Ticket::TicketCreate;
use Kernel::GenericInterface::Operation::Ticket::SessionIDGet;
use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

# set UserID to root because in public interface there is no user
$Self->{UserID} = 1;

# create ticket object
my $TicketObject = Kernel::System::Ticket->new( %{$Self} );

# TODO remove or use this code elsewhere
# # create a ticket
#my $TicketID = $TicketObject->TicketCreate(
#    Title        => 'Some Ticket Title',
#    Queue        => 'Raw',
#    Lock         => 'unlock',
#    Priority     => '3 normal',
#    State        => 'new',
#    CustomerID   => '123465',
#    CustomerUser => 'customer@example.com',
#    OwnerID      => 1,
#    UserID       => 1,
#);
#
# # sanity check
#$Self->True(
#    $TicketID,
#    "TicketCreate() successful for Ticket ID $TicketID",
#);
#
# # get the Ticket entry
#my %TicketEntry = $TicketObject->TicketGet(
#    TicketID      => $TicketID,
#    DynamicFields => 0,
#    UserID        => $Self->{UserID},
#);
#
#$Self->True(
#    IsHashRefWithData( \%TicketEntry ),
#    "TicketGet() successful for Local TicketGet ID $TicketID",
#);
#

# helper object
my $HelperObject = Kernel::System::UnitTest::Helper->new(
    %{$Self},
    UnitTestObject => $Self,
);

# set webservice name
my $WebserviceName = '-Test-' . $HelperObject->GetRandomID();

# set UserID on 1
my $UserID = 1;

# create webservice object
my $WebserviceObject = Kernel::System::GenericInterface::Webservice->new( %{$Self} );
$Self->Is(
    'Kernel::System::GenericInterface::Webservice',
    ref $WebserviceObject,
    "Create webservice object",
);

my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name    => $WebserviceName,
    Config  => {},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $WebserviceID,
    "Added Webservice",
);

# get remote host with some precautions for certain unit test systems
my $Host;
my $FQDN = $Self->{ConfigObject}->Get('FQDN');

# try to resolve fqdn host
if ( $FQDN ne 'yourhost.example.com' && gethostbyname($FQDN) ) {
    $Host = $FQDN;
}

# try to resolve localhost instead
if ( !$Host && gethostbyname('localhost') ) {
    $Host = 'localhost';
}

# use hardcoded localhost ip address
if ( !$Host ) {
    $Host = '127.0.0.1';
}

# prepare webservice config
my $RemoteSystem =
    $Self->{ConfigObject}->Get('HttpType')
    . '://'
    . $Host
    . '/'
    . $Self->{ConfigObject}->Get('ScriptAlias')
    . '/nph-genericinterface.pl/WebserviceID/'
    . $WebserviceID;

my $WebserviceConfig = {

    #    Name => '',
    Description =>
        'Test for Ticket Connector using SOAP transport backend.',
    Debugger => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    Provider => {
        Transport => {
            Type   => 'HTTP::SOAP',
            Config => {
                MaxLength => 10000000,
                NameSpace => 'http://otrs.org/SoapTestInterface/',
                Endpoint  => $RemoteSystem,
            },
        },
        Operation => {
            TicketCreate => {
                Type => 'Ticket::TicketCreate',
            },
            SessionIDGet => {
                Type => 'Ticket::SessionIDGet',
            },
        },
    },
    Requester => {
        Transport => {
            Type   => 'HTTP::SOAP',
            Config => {
                NameSpace => 'http://otrs.org/SoapTestInterface/',
                Encoding  => 'UTF-8',
                Endpoint  => $RemoteSystem,
            },
        },
        Invoker => {
            TicketCreate => {
                Type => 'Test::TestSimple',
            },
            SessionIDGet => {
                Type => 'Test::TestSimple',
            },
        },
    },
};

# update webservice with real config
my $WebserviceUpdate = $WebserviceObject->WebserviceUpdate(
    ID      => $WebserviceID,
    Name    => $WebserviceName,
    Config  => $WebserviceConfig,
    ValidID => 1,
    UserID  => $UserID,
);
$Self->True(
    $WebserviceUpdate,
    "Updated Webservice $WebserviceID - $WebserviceName",
);

# Get SessionID
# create requester object
my $RequesterSessionObject = Kernel::GenericInterface::Requester->new( %{$Self} );
$Self->Is(
    'Kernel::GenericInterface::Requester',
    ref $RequesterSessionObject,
    "SessionID - Create requester object",
);

# start requester with our webservice
my $UserLogin              = 'root@localhost';
my $Password               = 'root';
my $RequesterSessionResult = $RequesterSessionObject->Run(
    WebserviceID => $WebserviceID,
    Invoker      => 'SessionIDGet',
    Data         => {
        UserLogin => $UserLogin,
        Password  => $Password,
    },
);

my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};
my @Tests        = (
    {
        Name           => 'Empty Request',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'No Article',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket => {
                Test => 1,
            },
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'Invalid Ticket',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket  => 1,
            Article => {
                Test => 1,
            },
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'Invalid Article',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket => {
                Test => 1,
            },
            Article => 1,
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'Invalid DynamicField',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket => {
                Test => 1,
            },
            Article => {
                Test => 1,
            },
            DynamicField => 1,
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'Invalid Attachment',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket => {
                Test => 1,
            },
            Article => {
                Test => 1,
            },
            DynamicField => {
                Test => 1,
            },
            Attachment => 1,
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },
    {
        Name           => 'Missing Title',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
            Ticket => {
                Test => 1,
            },
            Article => {
                Test => 1,
            },
            DynamicField => {
                Test => 1,
            },
            Attachment => {
                Test => 1,
            },
        },
        ExpectedData => {
            Data => {
                Error => {
                    ErrorCode => 'TicketCreate.MissingParameter',
                    }
            },
            Success => 1
        },
        Operation => 'TicketCreate',
    },

#TODO remove this commented code
#    {
#        Name           => 'Test 2',
#        SuccessRequest => 1,
#        RequestData    => {
#            TicketID => 'NotTicketID',
#        },
#        ExpectedReturnLocalData => {
#            Data => {
#                Error => {
#                    ErrorCode => 'TicketGet.NotValidTicketID',
#                    ErrorMessage =>
#                        'TicketGet: Could not get Ticket data in Kernel::GenericInterface::Operation::Ticket::TicketGet::Run()'
#                    }
#            },
#            Success => 1
#        },
#        ExpectedReturnRemoteData => {
#            Data => {
#                Error => {
#                    ErrorCode => 'TicketGet.NotValidTicketID',
#                    ErrorMessage =>
#                        'TicketGet: Could not get Ticket data in Kernel::GenericInterface::Operation::Ticket::TicketGet::Run()'
#                    }
#            },
#            Success => 1
#        },
#        Operation => 'TicketGet',
#    },
#    {
#        Name           => 'Test 3',
#        SuccessRequest => '1',
#        RequestData    => {
#            TicketID => $TicketID,
#        },
#        ExpectedReturnRemoteData => {
#            Success => 1,
#            Data    => {
#                Item => {
#                    Ticket => {%TicketEntry},
#                },
#            },
#        },
#        ExpectedReturnLocalData => {
#            Success => 1,
#            Data    => {
#                Item => [
#                    {
#                        Ticket => {%TicketEntry},
#                    }
#                ],
#            },
#        },
#        Operation => 'TicketGet',
#    },

);

# debugger object
my $DebuggerObject = Kernel::GenericInterface::Debugger->new(
    %{$Self},
    DebuggerConfig => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    WebserviceID      => $WebserviceID,
    CommunicationType => 'Provider',
);
$Self->Is(
    ref $DebuggerObject,
    'Kernel::GenericInterface::Debugger',
    'DebuggerObject instanciate correctly',
);

for my $Test (@Tests) {

    # create local object
    my $LocalObject = "Kernel::GenericInterface::Operation::Ticket::$Test->{Operation}"->new(
        %{$Self},
        DebuggerObject => $DebuggerObject,
        WebserviceID   => $WebserviceID,
    );

    $Self->Is(
        "Kernel::GenericInterface::Operation::Ticket::$Test->{Operation}",
        ref $LocalObject,
        "$Test->{Name} - Create local object",
    );

    # start requester with our webservice
    my $LocalResult = $LocalObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
            UserLogin => $UserLogin,
            Password  => $Password,
            %{ $Test->{RequestData} },
            }
    );

    # check result
    $Self->Is(
        'HASH',
        ref $LocalResult,
        "$Test->{Name} - Local result structure is valid",
    );

    # create requester object
    my $RequesterObject = Kernel::GenericInterface::Requester->new( %{$Self} );
    $Self->Is(
        'Kernel::GenericInterface::Requester',
        ref $RequesterObject,
        "$Test->{Name} - Create requester object",
    );

    # start requester with our webservice
    my $RequesterResult = $RequesterObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
            SessionID => $NewSessionID,
            %{ $Test->{RequestData} },
            }
    );

    # check result
    $Self->Is(
        'HASH',
        ref $RequesterResult,
        "$Test->{Name} - Requester result structure is valid",
    );

    $Self->Is(
        $RequesterResult->{Success},
        $Test->{SuccessRequest},
        "$Test->{Name} - Requester successful result",
    );

    if ( $Test->{SuccessCreate} ) {

    }
    else {
        $Self->False(
            $LocalResult->{TicketID},
            "$Test->{Name} - Local result TicketID with false.",
        );
        $Self->False(
            $LocalResult->{TicketNumber},
            "$Test->{Name} - Local result TicketNumber with false.",
        );
        $Self->False(
            $LocalResult->{ArticleID},
            "$Test->{Name} - Local result ArticleID with false.",
        );
        $Self->Is(
            $LocalResult->{Data}->{Error}->{ErrorCode},
            $Test->{ExpectedData}->{Data}->{Error}->{ErrorCode},
            "$Test->{Name} - Local result ErrorCode matched with expected local call result.",
        );
        $Self->True(
            $LocalResult->{Data}->{Error}->{ErrorMessage},
            "$Test->{Name} - Local result ErrorMessage with true.",
        );
        $Self->IsNot(
            $LocalResult->{Data}->{Error}->{ErrorMessage},
            '',
            "$Test->{Name} - Local result ErrorMessage is not empty.",
        );
        $Self->Is(
            $LocalResult->{ErrorMessage},
            $LocalResult->{Data}->{Error}->{ErrorCode}
                . ': '
                . $LocalResult->{Data}->{Error}->{ErrorMessage},
            "$Test->{Name} - Local result ErrorMessage (outside Data hash) matched with concatenation"
                . " of ErrorCode and ErrorMessage within Data hash.",
        );

        # remove ErrorMessage parameter from direct call
        # result to be consistent with SOAP call result
        if ( $LocalResult->{ErrorMessage} ) {
            delete $LocalResult->{ErrorMessage};
        }

        # sanity check
        $Self->False(
            $LocalResult->{ErrorMessage},
            "$Test->{Name} - Local result ErroMessage (outsise Data hash) got removed to compare"
                . " local and remote tests.",
        );

        $Self->IsDeeply(
            $LocalResult,
            $RequesterResult,
            "$Test->{Name} - Local result matched with remote result.",
        );
    }
}

# clean up webservice
my $WebserviceDelete = $WebserviceObject->WebserviceDelete(
    ID     => $WebserviceID,
    UserID => $UserID,
);
$Self->True(
    $WebserviceDelete,
    "Deleted Webservice $WebserviceID",
);

# delete the ticket
#my $TicketDelete = $TicketObject->TicketDelete(
#    TicketID => $TicketID,
#    UserID   => 1,
#);
#
# # sanity check
#$Self->True(
#    $TicketDelete,
#    "TicketDelete() successful for Ticket ID $TicketID",
#);

1;
