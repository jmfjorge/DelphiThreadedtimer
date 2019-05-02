unit YMThreadTimer;

interface

uses
  Windows, Classes;

type
  TThreadedTimer = class;

  TTimerThread = class(TThread)
  private
    FOwner: TThreadedTimer;
    FInterval: Cardinal;
    FStop: THandle;
  protected
    procedure Execute; override;
  end;

  TThreadedTimer = class(TComponent)
  private
    FOnTimer: TNotifyEvent;
    FTimerThread: TTimerThread;
    FEnabled,
    FAllowZero: Boolean;
    procedure SetEnabled(Value: Boolean);
    function GetInterval: Cardinal;
    procedure SetInterval(Value: Cardinal);
    function GetThreadPriority: TThreadPriority;
    procedure SetThreadPriority(Value: TThreadPriority);
    procedure ExecuteTimer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

  published
    property AllowZero: Boolean read FAllowZero write FAllowZero default False;
    property Enabled: Boolean read FEnabled write SetEnabled default False;
    property Interval: Cardinal read GetInterval write SetInterval default 1000;
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
    property ThreadPriority: TThreadPriority read GetThreadPriority  write SetThreadPriority default tpNormal;
  end;

procedure Register;

implementation

{ TTimerThread }

procedure TTimerThread.Execute;
begin
  repeat
    try
      if WaitForSingleObject(FStop, FInterval) = WAIT_TIMEOUT then
        Synchronize(FOwner.ExecuteTimer);
    except
    end;
  until Terminated;
end;

{ TThreadedTimer }

constructor TThreadedTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimerThread := TTimerThread.Create(True);
  with FTimerThread do
  begin
    FOwner := Self;
    Priority := tpNormal;
    FInterval := 100;

    // Event is completely manipulated by TYMThreadedTimer object
    FStop := CreateEvent(nil, False, False, nil);
  end;
end;

destructor TThreadedTimer.Destroy;
begin
  with FTimerThread do
  begin
    FEnabled := False;
    
    Terminate;

    // When this method is called we must be confident that the event handle was not closed
    SetEvent(FStop);
    if Suspended then
      Resume;
    WaitFor;
    CloseHandle(FStop);  // Close event handle in the primary thread
    Free;
  end;
  inherited Destroy;
end;

procedure TThreadedTimer.ExecuteTimer;
begin

  // We have to check FEnabled in the primary thread
  // Check if is there OnTimer Event
  // Check if it's not destorying
  if FEnabled and Assigned(FOnTimer) and not (csDestroying in ComponentState) then
    try
      FOnTimer(Self);
    except
    end;
end;

procedure TThreadedTimer.SetEnabled(Value: Boolean);
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    if FEnabled then
    begin
      if (FTimerThread.FInterval > 0) or
        ((FTimerThread.FInterval = 0) and FAllowZero) then
      begin
        SetEvent(FTimerThread.FStop);
        FTimerThread.Resume;
      end;
    end
    else
      FTimerThread.Suspend;
  end;
end;

function TThreadedTimer.GetInterval: Cardinal;
begin
  Result := FTimerThread.FInterval;
end;

procedure TThreadedTimer.SetInterval(Value: Cardinal);
var
  PrevEnabled: Boolean;
begin
  if Value <> FTimerThread.FInterval then
  begin
    PrevEnabled := FEnabled;
    Enabled := False;
    FTimerThread.FInterval := Value;
    Enabled := PrevEnabled;
  end;
end;

function TThreadedTimer.GetThreadPriority: TThreadPriority;
begin
  Result := FTimerThread.Priority;
end;

procedure TThreadedTimer.SetThreadPriority(Value: TThreadPriority);
begin
  FTimerThread.Priority := Value;
end;

procedure Register;
begin
   RegisterComponents('YoungArts', [TThreadedTimer]);
end;

end.


