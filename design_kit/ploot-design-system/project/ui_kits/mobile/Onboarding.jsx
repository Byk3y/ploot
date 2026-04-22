// Ploot onboarding — 4 screens designed to let the brand voice land.
// Welcome → Name + Goal → First Task → Notifications.

function OnboardingFlow({ initialStep = 0, onDone }) {
  const [step, setStep] = useState(initialStep);
  const [name, setName] = useState('');
  const [goal, setGoal] = useState(null);
  const [firstTask, setFirstTask] = useState('');

  const next = () => setStep(s => Math.min(s + 1, 3));
  const back = () => setStep(s => Math.max(s - 1, 0));

  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      background: 'var(--bg)', position: 'relative', overflow: 'hidden',
    }}>
      {/* Status bar spacer */}
      <div style={{ height: 54, flexShrink: 0 }} />

      {/* Step indicator + back */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '12px 20px', flexShrink: 0,
      }}>
        <button
          onClick={back}
          disabled={step === 0}
          style={{
            width: 36, height: 36, borderRadius: 'var(--r-full)',
            background: step === 0 ? 'transparent' : 'var(--bg-elevated)',
            border: step === 0 ? '1.5px solid transparent' : '1.5px solid var(--border-ink)',
            boxShadow: step === 0 ? 'none' : 'var(--shadow-pop)',
            opacity: step === 0 ? 0 : 1,
            cursor: step === 0 ? 'default' : 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: 0,
          }}
        >
          <Icon name="arrow-left" size={18} />
        </button>

        {/* Dots */}
        <div style={{ display: 'flex', gap: 6 }}>
          {[0, 1, 2, 3].map(i => (
            <div
              key={i}
              style={{
                width: i === step ? 24 : 8, height: 8,
                borderRadius: 'var(--r-full)',
                background: i <= step ? 'var(--primary)' : 'var(--bg-sunken)',
                border: '1.5px solid var(--border-ink)',
                transition: 'width 320ms var(--ease-spring)',
              }}
            />
          ))}
        </div>

        <button
          onClick={() => onDone && onDone({ name, goal, firstTask })}
          style={{
            fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 500,
            color: 'var(--fg3)', background: 'transparent',
            border: 'none', cursor: 'pointer', padding: '6px 8px',
          }}
        >
          Skip
        </button>
      </div>

      {/* Content area */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', position: 'relative' }}>
        {step === 0 && <OnbWelcome onNext={next} />}
        {step === 1 && <OnbNameGoal name={name} setName={setName} goal={goal} setGoal={setGoal} onNext={next} />}
        {step === 2 && <OnbFirstTask name={name} firstTask={firstTask} setFirstTask={setFirstTask} onNext={next} />}
        {step === 3 && <OnbNotifications onDone={() => onDone && onDone({ name, goal, firstTask })} />}
      </div>
    </div>
  );
}

// ============================================================
// STEP 0 — Welcome
// ============================================================
function OnbWelcome({ onNext }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      padding: '0 28px 32px', alignItems: 'center', textAlign: 'center',
    }}>
      {/* Mascot illustration */}
      <div style={{
        flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative', width: '100%',
      }}>
        <div style={{
          width: 240, height: 240, borderRadius: 'var(--r-full)',
          background: 'var(--ploot-butter-100)',
          border: '2.5px solid var(--border-ink)',
          boxShadow: 'var(--shadow-pop-lg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          position: 'relative',
        }}>
          <img src="../../assets/mascot-ploot.svg" width="180" height="180" alt="" />
          {/* Floating decorative elements */}
          <div style={{
            position: 'absolute', top: -12, right: -16, width: 44, height: 44,
            borderRadius: 'var(--r-full)', background: 'var(--ploot-plum-500)',
            border: '2px solid var(--border-ink)', boxShadow: 'var(--shadow-pop)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transform: 'rotate(12deg)',
          }}>
            <span style={{ fontSize: 22 }}>✨</span>
          </div>
          <div style={{
            position: 'absolute', bottom: 8, left: -20, width: 36, height: 36,
            borderRadius: 'var(--r-full)', background: 'var(--ploot-sky-500)',
            border: '2px solid var(--border-ink)', boxShadow: 'var(--shadow-pop)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transform: 'rotate(-8deg)',
          }}>
            <span style={{ fontSize: 18 }}>☁</span>
          </div>
        </div>
      </div>

      {/* Copy */}
      <div style={{ paddingBottom: 24 }}>
        <h1 style={{
          fontFamily: 'var(--font-display)', fontSize: 40, fontWeight: 500,
          letterSpacing: '-0.02em', margin: '0 0 12px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 80, "opsz" 100',
          lineHeight: 1.05,
        }}>
          Hi, I'm <span style={{ color: 'var(--primary)' }}>Ploot</span>.
        </h1>
        <p style={{
          fontFamily: 'var(--font-display)', fontStyle: 'italic', fontWeight: 400,
          fontSize: 20, color: 'var(--fg2)', margin: '0 0 6px',
          fontVariationSettings: '"SOFT" 100',
          lineHeight: 1.3,
        }}>
          Your surprisingly cheerful<br/>task companion.
        </p>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 15, color: 'var(--fg3)',
          margin: '16px 0 0', lineHeight: 1.5, maxWidth: 280,
        }}>
          No pressure. No streak-shaming. Just a place to put the stuff.
        </p>
      </div>

      <Button variant="primary" size="lg" fullWidth onClick={onNext}>
        Let's go →
      </Button>
    </div>
  );
}

// ============================================================
// STEP 1 — Name + Goal
// ============================================================
function OnbNameGoal({ name, setName, goal, setGoal, onNext }) {
  const goals = [
    { id: 'work',    label: 'Work stuff',         emoji: '💼', hint: 'deadlines, deliverables' },
    { id: 'home',    label: 'Home stuff',         emoji: '🏡', hint: 'laundry, bills, life' },
    { id: 'creative',label: 'A creative project', emoji: '🎨', hint: 'the novel. the album.' },
    { id: 'habits',  label: 'Build new habits',   emoji: '🌱', hint: 'morning routines etc.' },
    { id: 'all',     label: 'Honestly? Everything.', emoji: '🌀', hint: 'a full life operating system' },
  ];

  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      padding: '8px 24px 24px', overflow: 'auto',
    }}>
      <h2 style={{
        fontFamily: 'var(--font-display)', fontSize: 32, fontWeight: 500,
        letterSpacing: '-0.018em', margin: '0 0 8px', color: 'var(--fg1)',
        fontVariationSettings: '"SOFT" 60, "opsz" 100',
        lineHeight: 1.1,
      }}>
        What should I call you?
      </h2>
      <p style={{
        fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
        margin: '0 0 16px',
      }}>
        Just your first name. I'll be polite about it.
      </p>

      <input
        autoFocus
        value={name}
        onChange={e => setName(e.target.value)}
        placeholder="Your name"
        style={{
          width: '100%', padding: '14px 16px',
          fontFamily: 'var(--font-sans)', fontSize: 18, fontWeight: 500,
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-md)',
          boxShadow: 'var(--shadow-pop)',
          outline: 'none', color: 'var(--fg1)',
          boxSizing: 'border-box',
          marginBottom: 28,
        }}
      />

      <div style={{
        fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600,
        textTransform: 'uppercase', letterSpacing: '0.1em',
        color: 'var(--fg3)', marginBottom: 12,
      }}>
        What's on your mind lately?
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {goals.map(g => {
          const selected = goal === g.id;
          return (
            <button
              key={g.id}
              onClick={() => setGoal(g.id)}
              style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 14px',
                background: selected ? 'var(--ploot-clay-100)' : 'var(--bg-elevated)',
                border: selected ? '1.5px solid var(--primary)' : '1.5px solid var(--border-ink)',
                borderRadius: 'var(--r-md)',
                boxShadow: selected ? '0 2px 0 var(--primary)' : 'var(--shadow-pop)',
                cursor: 'pointer', textAlign: 'left',
                transition: 'all 140ms var(--ease-spring)',
                transform: selected ? 'translateY(-1px)' : 'translateY(0)',
              }}
            >
              <div style={{
                width: 40, height: 40, flexShrink: 0,
                borderRadius: 'var(--r-sm)',
                background: selected ? 'var(--bg-elevated)' : 'var(--bg-sunken)',
                border: '1.5px solid var(--border-ink)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 20,
              }}>
                {g.emoji}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: 'var(--font-sans)', fontSize: 15, fontWeight: 600,
                  color: 'var(--fg1)',
                }}>
                  {g.label}
                </div>
                <div style={{
                  fontFamily: 'var(--font-sans)', fontSize: 12,
                  color: 'var(--fg3)', marginTop: 2,
                }}>
                  {g.hint}
                </div>
              </div>
              {selected && (
                <div style={{
                  width: 22, height: 22, borderRadius: 'var(--r-full)',
                  background: 'var(--primary)', color: 'white',
                  border: '1.5px solid var(--border-ink)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0,
                }}>
                  <Icon name="check" size={14} stroke={3} />
                </div>
              )}
            </button>
          );
        })}
      </div>

      <div style={{ marginTop: 'auto', paddingTop: 20 }}>
        <Button
          variant="primary" size="lg" fullWidth onClick={onNext}
          disabled={!name.trim() || !goal}
        >
          Continue
        </Button>
      </div>
    </div>
  );
}

// ============================================================
// STEP 2 — First task
// ============================================================
function OnbFirstTask({ name, firstTask, setFirstTask, onNext }) {
  const suggestions = [
    "Drink a glass of water",
    "Text someone I miss",
    "Tidy one surface",
    "Take a real lunch break",
  ];

  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      padding: '8px 24px 24px',
    }}>
      <h2 style={{
        fontFamily: 'var(--font-display)', fontSize: 30, fontWeight: 500,
        letterSpacing: '-0.018em', margin: '0 0 8px', color: 'var(--fg1)',
        fontVariationSettings: '"SOFT" 60, "opsz" 100',
        lineHeight: 1.1,
      }}>
        {name ? `Okay ${name}. ` : ''}Let's put one thing on the list.
      </h2>
      <p style={{
        fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
        margin: '0 0 20px', lineHeight: 1.5,
      }}>
        The satisfaction of checking something off is scientifically real. Probably.
      </p>

      {/* Task input — styled like a full task card */}
      <div style={{
        padding: '14px 14px', background: 'var(--bg-elevated)',
        border: '1.5px solid var(--border-ink)',
        borderRadius: 'var(--r-md)',
        boxShadow: 'var(--shadow-pop)',
        display: 'flex', alignItems: 'center', gap: 12,
        marginBottom: 20,
      }}>
        <div style={{
          width: 24, height: 24, flexShrink: 0,
          borderRadius: 'var(--r-full)',
          border: '2px solid var(--border-strong)',
        }} />
        <input
          autoFocus
          value={firstTask}
          onChange={e => setFirstTask(e.target.value)}
          placeholder="Type your first task…"
          style={{
            flex: 1, padding: 0,
            fontFamily: 'var(--font-sans)', fontSize: 16, fontWeight: 500,
            background: 'transparent', border: 'none',
            outline: 'none', color: 'var(--fg1)',
          }}
        />
      </div>

      <div style={{
        fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600,
        textTransform: 'uppercase', letterSpacing: '0.1em',
        color: 'var(--fg3)', marginBottom: 10,
      }}>
        Stuck? Try one of these
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {suggestions.map(s => (
          <button
            key={s}
            onClick={() => setFirstTask(s)}
            style={{
              padding: '8px 14px',
              fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 500,
              background: 'var(--bg-elevated)',
              border: '1.5px solid var(--border-ink)',
              borderRadius: 'var(--r-full)',
              boxShadow: '0 1px 0 var(--border-ink)',
              cursor: 'pointer', color: 'var(--fg1)',
              transition: 'transform 100ms var(--ease-spring)',
            }}
          >
            {s}
          </button>
        ))}
      </div>

      <div style={{ marginTop: 'auto' }}>
        <Button
          variant="primary" size="lg" fullWidth onClick={onNext}
          disabled={!firstTask.trim()}
        >
          Add it to my list
        </Button>
      </div>
    </div>
  );
}

// ============================================================
// STEP 3 — Notifications
// ============================================================
function OnbNotifications({ onDone }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      padding: '8px 24px 24px', alignItems: 'center', textAlign: 'center',
    }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', width: '100%' }}>
        {/* Mock notification preview */}
        <div style={{
          width: '100%', maxWidth: 300, padding: '14px 16px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--shadow-pop-lg)',
          display: 'flex', gap: 12, alignItems: 'flex-start',
          transform: 'rotate(-1.5deg)',
          marginBottom: 28,
        }}>
          <div style={{
            width: 36, height: 36, flexShrink: 0,
            borderRadius: 'var(--r-sm)',
            background: 'var(--primary)',
            border: '1.5px solid var(--border-ink)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name="check" size={18} stroke={3} color="white" />
          </div>
          <div style={{ flex: 1, textAlign: 'left' }}>
            <div style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              marginBottom: 3,
            }}>
              <span style={{
                fontFamily: 'var(--font-sans)', fontSize: 12, fontWeight: 700,
                color: 'var(--fg1)', textTransform: 'uppercase', letterSpacing: '0.04em',
              }}>
                Ploot
              </span>
              <span style={{
                fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--fg3)',
              }}>
                now
              </span>
            </div>
            <div style={{
              fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 500,
              color: 'var(--fg1)', lineHeight: 1.3,
            }}>
              Hey, it's time to water the mysterious plant. 🪴
            </div>
          </div>
        </div>

        <h2 style={{
          fontFamily: 'var(--font-display)', fontSize: 30, fontWeight: 500,
          letterSpacing: '-0.018em', margin: '0 0 10px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 60, "opsz" 100',
          lineHeight: 1.1,
        }}>
          Should I poke you?
        </h2>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
          margin: '0 0 0', lineHeight: 1.55, maxWidth: 280,
        }}>
          I'll only send you a nudge when something's due. <br/>
          No "hey you haven't opened the app in 3 days" guilt trips. Promise.
        </p>
      </div>

      <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Button variant="primary" size="lg" fullWidth onClick={onDone}>
          Yes, send nudges
        </Button>
        <Button variant="ghost" size="lg" fullWidth onClick={onDone}>
          Maybe later
        </Button>
      </div>
    </div>
  );
}

Object.assign(window, { OnboardingFlow, OnbWelcome, OnbNameGoal, OnbFirstTask, OnbNotifications });
