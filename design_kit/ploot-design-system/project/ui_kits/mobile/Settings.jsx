// Ploot Settings screen — profile, notifications, appearance, about.
// Dark mode toggle lives here.

function PlootToggle({ on, onChange }) {
  return (
    <button
      onClick={() => onChange(!on)}
      style={{
        width: 48, height: 28, borderRadius: 'var(--r-full)',
        background: on ? 'var(--primary)' : 'var(--border-strong)',
        border: '1.5px solid var(--border-ink)',
        position: 'relative', cursor: 'pointer',
        transition: 'background 180ms var(--ease-out)',
        padding: 0, flexShrink: 0,
      }}
    >
      <span style={{
        position: 'absolute', top: 1, left: on ? 21 : 1,
        width: 22, height: 22, borderRadius: '50%',
        background: '#fff',
        border: '1.5px solid var(--border-ink)',
        transition: 'left 260ms var(--ease-spring)',
      }}/>
    </button>
  );
}

function SettingBlock({ icon, label, value, children }) {
  return (
    <div style={{ padding: '0 16px 10px' }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 14px',
        background: 'var(--bg-elevated)',
        border: '1.5px solid var(--border-ink)',
        borderRadius: 'var(--r-md)',
        boxShadow: 'var(--shadow-pop)',
      }}>
        <div style={{
          width: 32, height: 32, borderRadius: 'var(--r-sm)',
          background: 'var(--bg-sunken)',
          border: '1.5px solid var(--border-ink)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0,
        }}>
          <Icon name={icon} size={16} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
            color: 'var(--fg1)',
          }}>
            {label}
          </div>
          {value && <div style={{
            fontFamily: 'var(--font-sans)', fontSize: 12, color: 'var(--fg3)',
          }}>{value}</div>}
        </div>
        {children}
      </div>
    </div>
  );
}

function SettingsScreen({ theme = 'light', setTheme, onBack }) {
  const [notif, setNotif] = useState(true);
  const [sounds, setSounds] = useState(true);
  const [weekStart, setWeekStart] = useState('Mon');
  const [priority, setPriority] = useState('clay');

  const themes = [
    { id: 'light',    name: 'Light',    hint: 'the cream canvas',  bg: '#faf8f5', fg: '#1a1410', accent: '#ff6b35' },
    { id: 'cocoa',    name: 'Cocoa',    hint: 'clay on chocolate', bg: '#3a2a20', fg: '#fbf1e2', accent: '#ff7a3d' },
  ];

  const accentColors = [
    { id: 'clay',    var: 'var(--ploot-clay-500)',   name: 'Clay' },
    { id: 'forest',  var: 'var(--ploot-forest-500)', name: 'Forest' },
    { id: 'sky',     var: 'var(--ploot-sky-500)',    name: 'Sky' },
    { id: 'plum',    var: 'var(--ploot-plum-500)',   name: 'Plum' },
    { id: 'butter',  var: 'var(--ploot-butter-500)', name: 'Butter' },
  ];

  return (
    <ScreenFrame
      title="Settings"
      subtitle="Everything is adjustable. Even the mascot."
      leftAction={
        <button
          onClick={onBack}
          style={{
            width: 36, height: 36, borderRadius: 'var(--r-full)',
            background: 'var(--bg-elevated)',
            border: '1.5px solid var(--border-ink)',
            boxShadow: 'var(--shadow-pop)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', padding: 0,
          }}
        >
          <Icon name="arrow-left" size={18} />
        </button>
      }
    >
      {/* Profile card */}
      <div style={{ padding: '0 16px 20px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '16px 16px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--shadow-pop)',
        }}>
          <Avatar initials="LM" color="var(--ploot-butter-300)" size={56} />
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: 'var(--font-display)', fontSize: 20, fontWeight: 500,
              color: 'var(--fg1)', letterSpacing: '-0.01em',
              fontVariationSettings: '"SOFT" 40',
            }}>
              Lena M.
            </div>
            <div style={{
              fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg3)',
              textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 2,
            }}>
              37 day streak · pro plan
            </div>
          </div>
          <button style={{
            padding: '8px 14px',
            fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600,
            background: 'var(--bg-sunken)',
            border: '1.5px solid var(--border-ink)',
            borderRadius: 'var(--r-full)',
            cursor: 'pointer', color: 'var(--fg1)',
          }}>
            Edit
          </button>
        </div>
      </div>

      {/* Appearance */}
      <SectionHeader title="Appearance" />
      <div style={{ padding: '0 16px 10px' }}>
        <div style={{
          padding: '14px 14px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-md)',
          boxShadow: 'var(--shadow-pop)',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14,
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 'var(--r-sm)',
              background: 'var(--bg-sunken)',
              border: '1.5px solid var(--border-ink)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <Icon name="sun-moon" size={16} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
                color: 'var(--fg1)',
              }}>
                Theme
              </div>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 12, color: 'var(--fg3)',
              }}>
                Ploot doesn't do black. We do low-light.
              </div>
            </div>
          </div>

          {/* Theme picker — 2 cards side-by-side */}
          <div style={{
            display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
          }}>
            {themes.map(t => {
              const selected = theme === t.id;
              return (
                <button
                  key={t.id}
                  onClick={() => setTheme && setTheme(t.id)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 10,
                    padding: '10px 12px',
                    background: selected ? 'var(--ploot-clay-100)' : 'var(--bg-sunken)',
                    border: selected ? '1.5px solid var(--primary)' : '1.5px solid var(--border-ink)',
                    borderRadius: 'var(--r-md)',
                    boxShadow: selected ? '0 2px 0 var(--primary)' : '0 1px 0 var(--border-ink)',
                    cursor: 'pointer', textAlign: 'left',
                    transition: 'all 140ms var(--ease-spring)',
                    transform: selected ? 'translateY(-1px)' : 'translateY(0)',
                  }}
                >
                  {/* mini swatch preview */}
                  <div style={{
                    width: 40, height: 40, borderRadius: 'var(--r-sm)',
                    background: t.bg,
                    border: '1.5px solid var(--border-ink)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0, position: 'relative', overflow: 'hidden',
                  }}>
                    {/* a little dot of the accent */}
                    <div style={{
                      width: 14, height: 14, borderRadius: '50%',
                      background: t.accent,
                      border: '1.2px solid ' + t.fg,
                    }}/>
                    {/* a little text bar */}
                    <div style={{
                      position: 'absolute', bottom: 5, left: 5, right: 5,
                      height: 3, borderRadius: 2, background: t.fg, opacity: 0.55,
                    }}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600,
                      color: selected ? 'var(--ploot-clay-700)' : 'var(--fg1)',
                    }}>
                      {t.name}
                    </div>
                    <div style={{
                      fontFamily: 'var(--font-sans)', fontSize: 11,
                      color: selected ? 'var(--ploot-clay-700)' : 'var(--fg3)',
                      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>
                      {t.hint}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div style={{ padding: '0 16px 16px' }}>
        <div style={{
          padding: '14px 14px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-md)',
          boxShadow: 'var(--shadow-pop)',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12,
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 'var(--r-sm)',
              background: 'var(--bg-sunken)',
              border: '1.5px solid var(--border-ink)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <Icon name="palette" size={16} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
                color: 'var(--fg1)',
              }}>
                Accent color
              </div>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 12, color: 'var(--fg3)',
              }}>
                It's still clay-orange by default.
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10, paddingLeft: 42 }}>
            {accentColors.map(c => (
              <button
                key={c.id}
                onClick={() => setPriority(c.id)}
                title={c.name}
                style={{
                  width: 32, height: 32, borderRadius: 'var(--r-full)',
                  background: c.var,
                  border: priority === c.id ? '2.5px solid var(--border-ink)' : '1.5px solid var(--border-ink)',
                  boxShadow: priority === c.id ? '0 0 0 3px var(--bg-elevated), 0 0 0 4.5px var(--fg1)' : 'none',
                  cursor: 'pointer', padding: 0,
                  transition: 'all 140ms var(--ease-spring)',
                }}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Notifications */}
      <SectionHeader title="Notifications" />
      <SettingBlock icon="bell" label="Reminders" value={notif ? 'When tasks are due' : 'Off'}>
        <PlootToggle on={notif} onChange={setNotif} />
      </SettingBlock>
      <SettingBlock icon="volume-2" label="Sounds" value={sounds ? 'That satisfying click' : 'Silent mode'}>
        <PlootToggle on={sounds} onChange={setSounds} />
      </SettingBlock>

      {/* Calendar */}
      <SectionHeader title="Calendar" />
      <div style={{ padding: '0 16px 16px' }}>
        <div style={{
          padding: '14px 14px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-md)',
          boxShadow: 'var(--shadow-pop)',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 32, height: 32, borderRadius: 'var(--r-sm)',
            background: 'var(--bg-sunken)',
            border: '1.5px solid var(--border-ink)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <Icon name="calendar-days" size={16} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
              color: 'var(--fg1)',
            }}>
              Week starts on
            </div>
          </div>
          <div style={{ display: 'flex', gap: 4, padding: 3, background: 'var(--bg-sunken)', borderRadius: 'var(--r-full)', border: '1.5px solid var(--border-ink)' }}>
            {['Sun', 'Mon'].map(d => (
              <button
                key={d}
                onClick={() => setWeekStart(d)}
                style={{
                  padding: '6px 12px',
                  fontFamily: 'var(--font-sans)', fontSize: 12, fontWeight: 600,
                  background: weekStart === d ? 'var(--bg-elevated)' : 'transparent',
                  border: weekStart === d ? '1.5px solid var(--border-ink)' : '1.5px solid transparent',
                  borderRadius: 'var(--r-full)',
                  boxShadow: weekStart === d ? '0 1px 0 var(--border-ink)' : 'none',
                  cursor: 'pointer',
                  color: weekStart === d ? 'var(--fg1)' : 'var(--fg3)',
                }}
              >
                {d}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* About */}
      <SectionHeader title="About" />
      <div style={{ padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { icon: 'heart', label: 'Rate Ploot', hint: 'If you like it, I guess' },
          { icon: 'mail', label: 'Send feedback', hint: 'feedback@ploot.app' },
          { icon: 'book-open', label: 'Privacy policy', hint: 'Short version: we don\'t track you' },
          { icon: 'info', label: 'About Ploot', hint: 'v2.1.0 · Made in Brooklyn' },
        ].map(row => (
          <button
            key={row.label}
            style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '14px',
              background: 'var(--bg-elevated)',
              border: '1.5px solid var(--border-ink)',
              borderRadius: 'var(--r-md)',
              boxShadow: 'var(--shadow-pop)',
              cursor: 'pointer', textAlign: 'left', width: '100%',
            }}
          >
            <div style={{
              width: 32, height: 32, borderRadius: 'var(--r-sm)',
              background: 'var(--bg-sunken)',
              border: '1.5px solid var(--border-ink)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <Icon name={row.icon} size={16} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
                color: 'var(--fg1)',
              }}>
                {row.label}
              </div>
              <div style={{
                fontFamily: 'var(--font-sans)', fontSize: 12, color: 'var(--fg3)',
              }}>
                {row.hint}
              </div>
            </div>
            <Icon name="chevron-right" size={18} color="var(--fg3)" />
          </button>
        ))}
      </div>

      {/* Sign out */}
      <div style={{ padding: '8px 16px 40px' }}>
        <button style={{
          width: '100%', padding: '14px',
          fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
          background: 'transparent',
          border: '1.5px solid var(--border-strong)',
          borderRadius: 'var(--r-md)',
          cursor: 'pointer',
          color: 'var(--fg3)',
        }}>
          Sign out
        </button>
        <div style={{
          textAlign: 'center', marginTop: 20,
          fontFamily: 'var(--font-display)', fontStyle: 'italic',
          fontSize: 13, color: 'var(--fg3)',
          fontVariationSettings: '"SOFT" 100',
        }}>
          made with clay and caffeine.
        </div>
      </div>

      <div style={{ height: 80 }} />
    </ScreenFrame>
  );
}

// ============================================================
// Empty states
// ============================================================

function TodayEmpty({ name = "there" }) {
  const messages = [
    "All clear. Suspiciously clear.",
    "Nothing on the list. Touch grass.",
    "You, my friend, are done.",
  ];
  const msg = messages[0];
  return (
    <ScreenFrame
      title={
        <span>
          Today <span style={{ fontFamily: 'var(--font-display)', fontStyle: 'italic', fontWeight: 400, color: 'var(--fg3)', fontSize: 22, fontVariationSettings: '"SOFT" 100' }}>·&nbsp;a fresh start</span>
        </span>
      }
      subtitle={`Hi ${name}. Today is a blank page.`}
      rightAction={<Avatar initials={name[0]?.toUpperCase() || 'P'} color="var(--ploot-butter-300)" />}
    >
      <div style={{
        padding: '40px 32px', display: 'flex', flexDirection: 'column',
        alignItems: 'center', textAlign: 'center', flex: 1, justifyContent: 'center',
      }}>
        <div style={{
          width: 180, height: 180, borderRadius: 'var(--r-full)',
          background: 'var(--ploot-clay-100)',
          border: '2.5px solid var(--border-ink)',
          boxShadow: 'var(--shadow-pop-lg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 28, position: 'relative',
        }}>
          <img src="../../assets/illo-inbox-zero.svg" width="140" height="140" alt="" />
          {/* Sparkle */}
          <div style={{
            position: 'absolute', top: 8, right: 6, fontSize: 28,
            transform: 'rotate(12deg)',
          }}>
            ✦
          </div>
        </div>
        <h3 style={{
          fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 500,
          letterSpacing: '-0.015em', margin: '0 0 8px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 60',
          lineHeight: 1.1,
        }}>
          {msg}
        </h3>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
          margin: '0 0 24px', maxWidth: 260, lineHeight: 1.55,
        }}>
          Tap the big orange ＋ when something lands on your plate. Or don't. I'm not your boss.
        </p>
        <Button variant="primary" size="md">
          <Icon name="plus" size={16} stroke={3} /> Add your first task
        </Button>
      </div>
    </ScreenFrame>
  );
}

function ProjectsEmpty() {
  return (
    <ScreenFrame
      title="Projects"
      subtitle="Bigger things, broken down."
    >
      <div style={{
        padding: '40px 24px', display: 'flex', flexDirection: 'column',
        alignItems: 'center', textAlign: 'center', flex: 1, justifyContent: 'center',
      }}>
        {/* Three empty project cards stacked, playful */}
        <div style={{
          position: 'relative', width: 200, height: 140, marginBottom: 28,
        }}>
          {[
            { rotate: -8, top: 20, left: 0,  color: 'var(--ploot-sky-100)' },
            { rotate: 4,  top: 10, left: 50, color: 'var(--ploot-butter-100)' },
            { rotate: -2, top: 0,  left: 25, color: 'var(--ploot-clay-100)' },
          ].map((c, i) => (
            <div key={i} style={{
              position: 'absolute', top: c.top, left: c.left,
              width: 140, height: 100,
              borderRadius: 'var(--r-lg)',
              background: c.color,
              border: '2px solid var(--border-ink)',
              boxShadow: 'var(--shadow-pop)',
              transform: `rotate(${c.rotate}deg)`,
              padding: 12,
            }}>
              <div style={{
                width: 36, height: 4, borderRadius: 'var(--r-full)',
                background: 'var(--border-strong)', marginBottom: 8,
              }}/>
              <div style={{
                width: 80, height: 4, borderRadius: 'var(--r-full)',
                background: 'var(--border-strong)', marginBottom: 6,
              }}/>
              <div style={{
                width: 54, height: 4, borderRadius: 'var(--r-full)',
                background: 'var(--border-strong)',
              }}/>
            </div>
          ))}
        </div>

        <h3 style={{
          fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 500,
          letterSpacing: '-0.015em', margin: '0 0 8px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 60',
          lineHeight: 1.1,
        }}>
          Group your stuff.
        </h3>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
          margin: '0 0 24px', maxWidth: 260, lineHeight: 1.55,
        }}>
          Projects hold related tasks together — a trip, a launch, the novel you keep meaning to write.
        </p>
        <Button variant="primary" size="md">
          <Icon name="folder-plus" size={16} stroke={2.5} /> New project
        </Button>
      </div>
    </ScreenFrame>
  );
}

function CalendarEmpty() {
  return (
    <ScreenFrame
      title="Calendar"
      subtitle="Week of Apr 21 — a wide open field."
    >
      <div style={{
        padding: '32px 24px 24px', display: 'flex', flexDirection: 'column',
        alignItems: 'center', textAlign: 'center',
      }}>
        {/* Empty 7-day strip */}
        <div style={{
          width: '100%', display: 'flex', gap: 6, marginBottom: 36,
          padding: '16px 12px',
          background: 'var(--bg-elevated)',
          border: '1.5px solid var(--border-ink)',
          borderRadius: 'var(--r-lg)',
          boxShadow: 'var(--shadow-pop)',
        }}>
          {['M','T','W','T','F','S','S'].map((d, i) => (
            <div key={i} style={{
              flex: 1, display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 6,
            }}>
              <span style={{
                fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 600,
                color: 'var(--fg3)',
              }}>{d}</span>
              <div style={{
                width: 28, height: 28, borderRadius: 'var(--r-full)',
                background: i === 1 ? 'var(--primary)' : 'var(--bg-sunken)',
                border: i === 1 ? '1.5px solid var(--border-ink)' : '1.5px dashed var(--border-strong)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600,
                color: i === 1 ? 'white' : 'var(--fg3)',
              }}>
                {21 + i}
              </div>
              <div style={{
                width: 4, height: 4, borderRadius: 'var(--r-full)',
                background: 'transparent',
              }}/>
            </div>
          ))}
        </div>

        <h3 style={{
          fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 500,
          letterSpacing: '-0.015em', margin: '0 0 8px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 60',
          lineHeight: 1.1,
        }}>
          A whole week<br/>of possibility.
        </h3>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
          margin: '0 0 24px', maxWidth: 260, lineHeight: 1.55,
        }}>
          Schedule a task by giving it a date. It'll show up here with the rest of the week.
        </p>
        <Button variant="secondary" size="md">
          Connect your calendar
        </Button>
      </div>
    </ScreenFrame>
  );
}

function DoneEmpty({ name = "there" }) {
  return (
    <ScreenFrame
      title="Done"
      subtitle="Your hall of tiny victories."
    >
      <div style={{
        padding: '40px 32px', display: 'flex', flexDirection: 'column',
        alignItems: 'center', textAlign: 'center', flex: 1, justifyContent: 'center',
      }}>
        {/* Empty checkbox illustration, big */}
        <div style={{
          width: 180, height: 180, borderRadius: 'var(--r-full)',
          background: 'var(--ploot-forest-100)',
          border: '2.5px solid var(--border-ink)',
          boxShadow: 'var(--shadow-pop-lg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 28, position: 'relative',
        }}>
          <div style={{
            width: 96, height: 96, borderRadius: 'var(--r-lg)',
            background: 'var(--bg-elevated)',
            border: '2.5px solid var(--border-ink)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name="check" size={56} stroke={3} color="var(--border-strong)" />
          </div>
        </div>

        <h3 style={{
          fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 500,
          letterSpacing: '-0.015em', margin: '0 0 8px', color: 'var(--fg1)',
          fontVariationSettings: '"SOFT" 60',
          lineHeight: 1.1,
        }}>
          Nothing crushed yet.
        </h3>
        <p style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg3)',
          margin: '0 0 24px', maxWidth: 260, lineHeight: 1.55,
        }}>
          Check something off — any task counts. Even the easy ones. <span style={{ fontStyle: 'italic', fontFamily: 'var(--font-display)' }}>Especially the easy ones.</span>
        </p>

        {/* Fake streak calendar */}
        <div style={{ display: 'flex', gap: 6 }}>
          {Array.from({ length: 7 }).map((_, i) => (
            <div key={i} style={{
              width: 18, height: 18, borderRadius: 5,
              background: 'var(--bg-sunken)',
              border: '1.5px dashed var(--border-strong)',
            }}/>
          ))}
        </div>
        <div style={{
          marginTop: 10,
          fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 600,
          textTransform: 'uppercase', letterSpacing: '0.12em',
          color: 'var(--fg3)',
        }}>
          your 7-day streak starts here
        </div>
      </div>
    </ScreenFrame>
  );
}

Object.assign(window, { SettingsScreen, TodayEmpty, ProjectsEmpty, CalendarEmpty, DoneEmpty, PlootToggle, SettingBlock });
