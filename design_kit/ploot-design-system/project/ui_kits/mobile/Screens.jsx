// Screen components for Ploot mobile app

function TodayScreen({ tasks, onToggle, onOpen }) {
  const today = tasks.filter(t => t.section === 'today');
  const overdue = tasks.filter(t => t.section === 'overdue');
  const later = tasks.filter(t => t.section === 'later');
  const doneCount = today.filter(t => t.done).length;
  const totalCount = today.length;

  return (
    <ScreenFrame
      title={
        <span>
          Today <span style={{ fontFamily: 'var(--font-display)', fontStyle: 'italic', fontWeight: 400, color: 'var(--fg3)', fontSize: 22, fontVariationSettings: '"SOFT" 100' }}>·&nbsp;{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}</span>
        </span>
      }
      subtitle={totalCount > 0 ? `${doneCount} of ${totalCount} crushed. Keep going.` : "Nothing on the list. Suspicious."}
      rightAction={<Avatar initials="LM" color="var(--ploot-butter-300)" />}
    >
      {/* Progress bar */}
      <div style={{ padding: '0 16px 16px' }}>
        <div style={{
          height: 8, background: 'var(--bg-sunken)', borderRadius: 'var(--r-full)',
          border: '1.5px solid var(--border-ink)', overflow: 'hidden', position: 'relative',
        }}>
          <div style={{
            height: '100%', width: `${totalCount ? (doneCount / totalCount) * 100 : 0}%`,
            background: 'var(--primary)',
            transition: 'width 400ms var(--ease-spring)',
          }} />
        </div>
      </div>

      {overdue.length > 0 && (
        <>
          <SectionHeader title="Overdue" count={overdue.length} />
          {overdue.map(t => <TaskRow key={t.id} task={t} onToggle={v => onToggle(t.id, v)} onOpen={onOpen} />)}
        </>
      )}

      <SectionHeader title="Today" count={today.length} />
      {today.length > 0
        ? today.map(t => <TaskRow key={t.id} task={t} onToggle={v => onToggle(t.id, v)} onOpen={onOpen} />)
        : (
          <Empty
            illustration="../../assets/illo-all-done.svg"
            title="All done!"
            subtitle="You finished today's list. Take a victory lap — you've earned it."
          />
        )
      }

      {later.length > 0 && (
        <>
          <SectionHeader title="Later this week" count={later.length} />
          {later.map(t => <TaskRow key={t.id} task={t} onToggle={v => onToggle(t.id, v)} onOpen={onOpen} />)}
        </>
      )}
      <div style={{ height: 120 }}/>
    </ScreenFrame>
  );
}

function ProjectsScreen({ projects, onOpen }) {
  return (
    <ScreenFrame
      title="Projects"
      subtitle="Where the plans live."
      rightAction={<button style={{ width: 36, height: 36, borderRadius: '50%', border: '2px solid var(--border-ink)', background: 'var(--bg-elevated)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><Icon name="plus" size={18}/></button>}
    >
      <div style={{ padding: '8px 16px 120px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {projects.map(p => (
          <Card key={p.id} interactive onClick={() => onOpen && onOpen(p)} padding={14}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{
                width: 44, height: 44, borderRadius: 12,
                background: p.color, display: 'flex', alignItems: 'center', justifyContent: 'center',
                border: '2px solid var(--border-ink)',
                fontSize: 22,
              }}>{p.emoji}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--fg1)', letterSpacing: '-0.005em' }}>{p.name}</div>
                <div style={{ fontSize: 13, color: 'var(--fg3)', marginTop: 2, display: 'flex', gap: 8, alignItems: 'center' }}>
                  <span>{p.openCount} open</span>
                  <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--fg3)' }} />
                  <span>{p.doneCount} done</span>
                </div>
              </div>
              <Icon name="chevron-right" size={18} color="var(--fg3)"/>
            </div>
            {/* Mini progress bar */}
            <div style={{
              marginTop: 12, height: 5, background: 'var(--bg-sunken)', borderRadius: 'var(--r-full)', overflow: 'hidden',
            }}>
              <div style={{
                height: '100%',
                width: `${p.doneCount / (p.openCount + p.doneCount) * 100}%`,
                background: p.color === 'var(--ploot-butter-300)' ? '#c49500' : p.color,
              }}/>
            </div>
          </Card>
        ))}
      </div>
    </ScreenFrame>
  );
}

function TaskDetailScreen({ task, onBack, onToggle }) {
  if (!task) return null;
  return (
    <ScreenFrame
      leftAction={
        <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: '50%', background: 'var(--bg-elevated)', border: '2px solid var(--border-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="arrow-left" size={18}/>
        </button>
      }
      rightAction={
        <button style={{ width: 40, height: 40, borderRadius: '50%', background: 'var(--bg-elevated)', border: '2px solid var(--border-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="more-horizontal" size={18}/>
        </button>
      }
    >
      <div style={{ padding: '8px 20px 40px' }}>
        <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
          <div style={{ paddingTop: 4 }}>
            <Checkbox size={32} checked={task.done} onChange={v => onToggle(task.id, v)} priority={task.priority} />
          </div>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: 30, lineHeight: 1.1, letterSpacing: '-0.015em',
            fontWeight: 500, margin: 0, color: 'var(--fg1)',
            textDecoration: task.done ? 'line-through' : 'none',
            opacity: task.done ? 0.5 : 1,
            flex: 1,
          }}>{task.title}</h1>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 20, marginLeft: 46 }}>
          {task.due && <Chip color="clay" icon="calendar">{task.due}</Chip>}
          {task.project && <Chip color="sky" icon="folder">{task.project[0].toUpperCase() + task.project.slice(1)}</Chip>}
          {task.priority === 'urgent' && <Chip color="plum" icon="flame">Urgent</Chip>}
          {task.tags && task.tags.map(t => <Chip key={t}>{t}</Chip>)}
        </div>

        {task.note && (
          <div style={{
            marginTop: 24, padding: 16,
            background: 'var(--ploot-butter-100)',
            border: '2px solid var(--border-ink)',
            borderRadius: 'var(--r-lg)',
            fontFamily: 'var(--font-sans)', fontSize: 15, lineHeight: 1.55, color: 'var(--fg1)',
            boxShadow: 'var(--shadow-pop)',
          }}>
            {task.note}
          </div>
        )}

        {task.subtasks && task.subtasks.length > 0 && (
          <div style={{ marginTop: 28 }}>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--fg2)', marginBottom: 10 }}>
              Sub-tasks · {task.subtasks.filter(s => s.done).length}/{task.subtasks.length}
            </div>
            {task.subtasks.map((s, i) => (
              <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
                <Checkbox size={20} checked={s.done} onChange={() => {}} />
                <span style={{ fontSize: 14, color: 'var(--fg1)', textDecoration: s.done ? 'line-through' : 'none', opacity: s.done ? 0.5 : 1 }}>{s.title}</span>
              </div>
            ))}
          </div>
        )}

        {/* Meta footer */}
        <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 10, padding: 14, background: 'var(--bg-sunken)', borderRadius: 'var(--r-md)' }}>
          <DetailRow icon="bell" label="Remind me" value="9:00 AM" />
          <DetailRow icon="repeat" label="Repeats" value={task.repeat || 'Never'} />
          <DetailRow icon="paperclip" label="Attachments" value={task.attachments ? `${task.attachments} files` : 'None'} />
        </div>
      </div>
    </ScreenFrame>
  );
}

function DetailRow({ icon, label, value }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14 }}>
      <Icon name={icon} size={16} color="var(--fg3)"/>
      <span style={{ color: 'var(--fg2)', flex: 1 }}>{label}</span>
      <span style={{ color: 'var(--fg1)', fontWeight: 500 }}>{value}</span>
    </div>
  );
}

function QuickAddSheet({ onClose, onAdd }) {
  const [title, setTitle] = useState('');
  const [note, setNote] = useState('');
  const [project, setProject] = useState('inbox');
  const [priority, setPriority] = useState('normal');
  const [due, setDue] = useState('today');
  const [time, setTime] = useState(null);
  const [reminder, setReminder] = useState(false);
  const [repeat, setRepeat] = useState('never');
  const [subtasks, setSubtasks] = useState([]);
  const [subInput, setSubInput] = useState('');
  const [focusedSection, setFocusedSection] = useState(null);

  // Playful placeholder rotation
  const placeholders = [
    "Water the mysterious plant",
    "Finally reply to that email",
    "Outline the Q3 pitch deck",
    "Touch grass",
    "Fold the laundry (yes, today)",
    "Call mom — she misses you",
  ];
  const [phIdx] = useState(() => Math.floor(Math.random() * placeholders.length));

  // Natural-language hint detection (visual only)
  const nlpHints = [];
  const lower = title.toLowerCase();
  if (/\btomorrow\b/.test(lower)) nlpHints.push({ type: 'date', label: 'tomorrow' });
  if (/\btoday\b/.test(lower))    nlpHints.push({ type: 'date', label: 'today' });
  if (/\b(mon|tue|wed|thu|fri|sat|sun)/.test(lower)) nlpHints.push({ type: 'date', label: 'day' });
  if (/\burgent\b|!!!/.test(lower)) nlpHints.push({ type: 'priority', label: 'urgent' });
  if (/\b@work\b/.test(lower)) nlpHints.push({ type: 'project', label: 'Work' });
  if (/\b@home\b/.test(lower)) nlpHints.push({ type: 'project', label: 'Home' });

  const dateOptions = [
    { id: 'today',     label: 'Today',     icon: 'sun',       hint: 'this very day' },
    { id: 'tomorrow',  label: 'Tomorrow',  icon: 'sunrise',   hint: 'future you\'s problem' },
    { id: 'weekend',   label: 'Weekend',   icon: 'coffee',    hint: 'saturday or thereabouts' },
    { id: 'nextweek',  label: 'Next week', icon: 'calendar-clock',  hint: 'the long game' },
    { id: 'someday',   label: 'Someday',   icon: 'infinity',  hint: 'honestly, who knows' },
  ];
  const timeSlots = ['8:00 AM','9:00 AM','10:00 AM','12:00 PM','2:00 PM','5:00 PM'];

  const projectOptions = [
    { id: 'inbox',   name: 'Inbox',     emoji: '📮', color: 'var(--fg3)' },
    { id: 'work',    name: 'Work',      emoji: '💼', color: 'var(--ploot-sky-500)' },
    { id: 'home',    name: 'Home',      emoji: '🏡', color: 'var(--ploot-forest-500)' },
    { id: 'side',    name: 'Side quest',emoji: '🚀', color: 'var(--ploot-plum-500)' },
    { id: 'errands', name: 'Errands',   emoji: '🛒', color: 'var(--ploot-butter-500)' },
    { id: 'reading', name: 'Reading',   emoji: '📚', color: 'var(--primary)' },
  ];

  const priorityOptions = [
    { id: 'normal', label: 'Normal', color: 'var(--fg3)',               ring: 'var(--border-strong)',     emoji: '' },
    { id: 'medium', label: 'Medium', color: 'var(--ploot-butter-500)',  ring: 'var(--ploot-butter-500)',  emoji: '⚡' },
    { id: 'high',   label: 'High',   color: 'var(--ploot-plum-500)',    ring: 'var(--ploot-plum-500)',    emoji: '❗' },
    { id: 'urgent', label: 'Urgent', color: 'var(--primary)',           ring: 'var(--primary)',           emoji: '🔥' },
  ];

  const repeatOptions = ['never', 'daily', 'weekly', 'monthly'];

  const currentProject = projectOptions.find(p => p.id === project) || projectOptions[0];
  const currentPriority = priorityOptions.find(p => p.id === priority) || priorityOptions[0];
  const currentDate = dateOptions.find(d => d.id === due) || dateOptions[0];

  function addSubtask() {
    if (!subInput.trim()) return;
    setSubtasks(s => [...s, { title: subInput.trim(), done: false, id: Date.now() }]);
    setSubInput('');
  }

  function removeSubtask(id) {
    setSubtasks(s => s.filter(x => x.id !== id));
  }

  function handleSubmit() {
    if (!title.trim()) return;
    onAdd({ title, project, priority, due: currentDate.label + (time ? `, ${time}` : ''), note, subtasks });
    onClose();
  }

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: 'rgba(26,20,16,0.5)',
      backdropFilter: 'blur(8px)',
      display: 'flex', alignItems: 'flex-end',
      opacity: 1,
      animation: 'ploot-fade-in 220ms var(--ease-out) both',
    }} onClick={onClose}>
      <div
        onClick={e => e.stopPropagation()}
        style={{
          width: '100%', height: '94%',
          background: 'var(--bg)',
          borderTopLeftRadius: 28, borderTopRightRadius: 28,
          border: '2px solid var(--border-ink)', borderBottom: 'none',
          display: 'flex', flexDirection: 'column',
          animation: 'ploot-slide-up 340ms var(--ease-spring) both',
          overflow: 'hidden',
        }}
      >
        {/* grabber + header bar */}
        <div style={{ padding: '10px 0 0' }}>
          <div style={{ width: 44, height: 5, background: 'var(--border-strong)', borderRadius: 'var(--r-full)', margin: '0 auto 10px' }} />
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '4px 16px 12px',
        }}>
          <button onClick={onClose} style={{
            fontFamily: 'var(--font-sans)', fontSize: 15, fontWeight: 500,
            color: 'var(--fg2)', background: 'transparent', border: 'none', cursor: 'pointer', padding: '6px 8px',
          }}>Cancel</button>
          <div style={{
            fontFamily: 'var(--font-display)', fontSize: 20, fontWeight: 600, letterSpacing: '-0.015em', color: 'var(--fg1)',
            fontVariationSettings: '"SOFT" 80',
          }}>
            New task
          </div>
          <Button
            variant="primary" size="sm"
            disabled={!title.trim()}
            onClick={handleSubmit}
            style={{ minWidth: 64 }}
          >Save</Button>
        </div>

        {/* Scrollable body */}
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '4px 16px 24px', minWidth: 0 }}>

          {/* BIG TITLE INPUT */}
          <div style={{
            background: 'var(--bg-elevated)',
            border: '2px solid ' + (focusedSection === 'title' ? 'var(--border-ink)' : 'var(--border)'),
            borderRadius: 'var(--r-lg)',
            boxShadow: focusedSection === 'title' ? 'var(--shadow-pop)' : 'none',
            padding: '16px 16px 12px',
            transition: 'all var(--dur-fast) var(--ease-out)',
            transform: focusedSection === 'title' ? 'translateY(-1px)' : 'none',
          }}>
            <textarea
              value={title}
              onChange={e => setTitle(e.target.value)}
              onFocus={() => setFocusedSection('title')}
              onBlur={() => setFocusedSection(null)}
              placeholder={placeholders[phIdx]}
              rows={1}
              autoFocus
              style={{
                width: '100%', border: 'none', outline: 'none', resize: 'none', background: 'transparent',
                fontFamily: 'var(--font-display)', fontSize: 24, fontWeight: 500,
                letterSpacing: '-0.015em', lineHeight: 1.2, color: 'var(--fg1)',
                fontVariationSettings: '"SOFT" 50',
                minHeight: 30, padding: 0,
              }}
            />
            <textarea
              value={note}
              onChange={e => setNote(e.target.value)}
              placeholder="Add a note..."
              rows={2}
              style={{
                width: '100%', border: 'none', outline: 'none', resize: 'none', background: 'transparent',
                fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg2)', lineHeight: 1.5,
                marginTop: 8, padding: 0,
              }}
            />

            {/* NLP hints */}
            {nlpHints.length > 0 && (
              <div style={{
                display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 10, paddingTop: 10,
                borderTop: '1px dashed var(--border)',
                animation: 'ploot-fade-in 200ms var(--ease-out)',
              }}>
                <span style={{ fontFamily: 'var(--font-mono)', fontSize: 10, color: 'var(--fg3)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em', paddingTop: 3 }}>I picked up:</span>
                {nlpHints.map((h, i) => (
                  <Chip key={i} color={h.type === 'date' ? 'clay' : h.type === 'priority' ? 'plum' : 'sky'} icon={h.type === 'date' ? 'calendar' : h.type === 'priority' ? 'flame' : 'folder'}>
                    {h.label}
                  </Chip>
                ))}
              </div>
            )}
          </div>

          {/* WHEN — date picker */}
          <SettingBlock icon="calendar" label="When" value={currentDate.label + (time ? ` · ${time}` : '')}>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
              {dateOptions.map(d => {
                const active = due === d.id;
                return (
                  <button
                    key={d.id}
                    onClick={() => setDue(d.id)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 6,
                      padding: '8px 12px', borderRadius: 12,
                      background: active ? 'var(--primary)' : 'var(--bg-elevated)',
                      color: active ? 'var(--on-primary)' : 'var(--fg1)',
                      border: '2px solid ' + (active ? 'var(--border-ink)' : 'var(--border)'),
                      boxShadow: active ? 'var(--shadow-pop)' : 'none',
                      transform: active ? 'translateY(-1px)' : 'none',
                      fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 600,
                      cursor: 'pointer',
                      transition: 'all var(--dur-fast) var(--ease-spring)',
                    }}
                  >
                    <Icon name={d.icon} size={14}/>
                    {d.label}
                  </button>
                );
              })}
            </div>

            {/* Time row */}
            <div style={{ marginTop: 14, paddingTop: 14, borderTop: '1px dashed var(--border)' }}>
              <div style={{ fontFamily: 'var(--font-mono)', fontSize: 10, color: 'var(--fg3)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 8 }}>
                Pick a time <span style={{ textTransform: 'none', color: 'var(--fg3)', opacity: 0.7 }}>· optional</span>
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {timeSlots.map(t => {
                  const active = time === t;
                  return (
                    <button
                      key={t} onClick={() => setTime(active ? null : t)}
                      style={{
                        padding: '6px 10px', borderRadius: 10,
                        background: active ? 'var(--border-ink)' : 'var(--bg-elevated)',
                        color: active ? 'var(--fg-inverse)' : 'var(--fg1)',
                        border: '1.5px solid ' + (active ? 'var(--border-ink)' : 'var(--border)'),
                        fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600,
                        cursor: 'pointer',
                        transition: 'all var(--dur-fast) var(--ease-out)',
                      }}
                    >{t}</button>
                  );
                })}
              </div>
            </div>
          </SettingBlock>

          {/* PROJECT — smart dropdown picker */}
          <ProjectPicker
            project={project}
            setProject={setProject}
            projectOptions={projectOptions}
            isOpen={focusedSection === 'project'}
            setOpen={(open) => setFocusedSection(open ? 'project' : null)}
          />


          {/* PRIORITY */}
          <SettingBlock icon="flag" label="Priority" value={currentPriority.label + (currentPriority.emoji ? ` ${currentPriority.emoji}` : '')}>
            <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
              {priorityOptions.map(p => {
                const active = priority === p.id;
                return (
                  <button
                    key={p.id}
                    onClick={() => setPriority(p.id)}
                    style={{
                      flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                      padding: '10px 6px', borderRadius: 12,
                      background: 'var(--bg-elevated)',
                      border: '2px solid ' + (active ? 'var(--border-ink)' : 'var(--border)'),
                      boxShadow: active ? 'var(--shadow-pop)' : 'none',
                      transform: active ? 'translateY(-1px)' : 'none',
                      cursor: 'pointer',
                      transition: 'all var(--dur-fast) var(--ease-spring)',
                    }}
                  >
                    <div style={{
                      width: 22, height: 22, borderRadius: '50%',
                      border: `2.5px solid ${p.ring}`,
                      background: p.id === 'urgent' && active ? p.color : 'transparent',
                      position: 'relative',
                    }}>
                      {p.emoji && <span style={{ position: 'absolute', top: -4, right: -8, fontSize: 12 }}>{p.emoji}</span>}
                    </div>
                    <span style={{ fontFamily: 'var(--font-sans)', fontSize: 11, fontWeight: 600, color: active ? 'var(--fg1)' : 'var(--fg2)' }}>{p.label}</span>
                  </button>
                );
              })}
            </div>
          </SettingBlock>

          {/* REMINDER + REPEAT inline */}
          <div style={{
            background: 'var(--bg-elevated)',
            border: '2px solid var(--border)',
            borderRadius: 'var(--r-lg)',
            padding: 14,
            marginTop: 12,
          }}>
            {/* Reminder toggle */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Icon name="bell" size={18} color="var(--fg2)"/>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, color: 'var(--fg1)' }}>Remind me</div>
                <div style={{ fontSize: 12, color: 'var(--fg3)' }}>{reminder ? (time || '9:00 AM') + ', day-of' : "We won't nag you"}</div>
              </div>
              <Toggle on={reminder} onChange={setReminder} />
            </div>

            <div style={{ height: 1, background: 'var(--border)', margin: '12px -14px' }}/>

            {/* Repeat */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Icon name="repeat" size={18} color="var(--fg2)"/>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, color: 'var(--fg1)' }}>Repeats</div>
                <div style={{ fontSize: 12, color: 'var(--fg3)', textTransform: 'capitalize' }}>{repeat === 'never' ? 'Just this once' : repeat}</div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
              {repeatOptions.map(r => {
                const active = repeat === r;
                return (
                  <button
                    key={r} onClick={() => setRepeat(r)}
                    style={{
                      flex: 1, padding: '8px 6px', borderRadius: 10,
                      background: active ? 'var(--border-ink)' : 'var(--bg-sunken)',
                      color: active ? 'var(--fg-inverse)' : 'var(--fg2)',
                      border: 'none',
                      fontFamily: 'var(--font-sans)', fontSize: 12, fontWeight: 600,
                      textTransform: 'capitalize', cursor: 'pointer',
                      transition: 'all var(--dur-fast)',
                    }}
                  >{r}</button>
                );
              })}
            </div>
          </div>

          {/* SUBTASKS */}
          <div style={{
            background: 'var(--bg-elevated)',
            border: '2px solid var(--border)',
            borderRadius: 'var(--r-lg)',
            padding: 14,
            marginTop: 12,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: subtasks.length ? 10 : 0 }}>
              <Icon name="list-checks" size={18} color="var(--fg2)"/>
              <div style={{ fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, color: 'var(--fg1)', flex: 1 }}>
                Break it down
              </div>
              {subtasks.length > 0 && (
                <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600, color: 'var(--fg3)' }}>
                  {subtasks.length} step{subtasks.length === 1 ? '' : 's'}
                </span>
              )}
            </div>

            {subtasks.map(s => (
              <div key={s.id} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '8px 0', borderBottom: '1px solid var(--border)',
                animation: 'ploot-fade-in 180ms var(--ease-out)',
              }}>
                <span style={{
                  width: 16, height: 16, borderRadius: '50%',
                  border: '2px solid var(--border-strong)', flexShrink: 0,
                }}/>
                <span style={{ flex: 1, fontSize: 14, color: 'var(--fg1)' }}>{s.title}</span>
                <button onClick={() => removeSubtask(s.id)} style={{
                  width: 22, height: 22, borderRadius: '50%', border: 'none',
                  background: 'var(--bg-sunken)', color: 'var(--fg3)',
                  cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Icon name="x" size={12}/>
                </button>
              </div>
            ))}

            <div style={{
              display: 'flex', alignItems: 'center', gap: 10,
              paddingTop: subtasks.length ? 8 : 10,
            }}>
              <Icon name="plus" size={16} color="var(--fg3)"/>
              <input
                type="text" value={subInput}
                onChange={e => setSubInput(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addSubtask(); } }}
                placeholder="Add a step"
                style={{
                  flex: 1, border: 'none', outline: 'none', background: 'transparent',
                  fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--fg1)',
                }}
              />
              {subInput.trim() && (
                <button onClick={addSubtask} style={{
                  padding: '4px 10px', borderRadius: 8,
                  background: 'var(--primary)', color: 'var(--on-primary)',
                  border: '1.5px solid var(--border-ink)',
                  fontSize: 11, fontWeight: 700, fontFamily: 'var(--font-sans)',
                  cursor: 'pointer', textTransform: 'uppercase', letterSpacing: '0.04em',
                }}>Add</button>
              )}
            </div>
          </div>

          {/* Attachments + quick actions */}
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            <QuickAction icon="paperclip" label="Attach"/>
            <QuickAction icon="map-pin" label="Location"/>
            <QuickAction icon="users" label="Assign"/>
          </div>

          <div style={{ height: 20 }}/>
        </div>
      </div>
    </div>
  );
}

function SettingBlock({ icon, label, value, children }) {
  return (
    <div style={{
      background: 'var(--bg-elevated)',
      border: '2px solid var(--border)',
      borderRadius: 'var(--r-lg)',
      padding: 14,
      marginTop: 12,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Icon name={icon} size={18} color="var(--fg2)"/>
        <div style={{ fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, color: 'var(--fg1)', flex: 1 }}>{label}</div>
        <span style={{ fontFamily: 'var(--font-sans)', fontSize: 13, color: 'var(--fg2)', fontWeight: 500 }}>{value}</span>
      </div>
      {children}
    </div>
  );
}

function Toggle({ on, onChange }) {
  return (
    <button
      onClick={() => onChange(!on)}
      style={{
        width: 44, height: 26, borderRadius: 'var(--r-full)',
        background: on ? 'var(--primary)' : 'var(--border-strong)',
        border: '2px solid var(--border-ink)',
        position: 'relative', cursor: 'pointer',
        transition: 'background var(--dur-fast) var(--ease-out)',
        padding: 0,
      }}
    >
      <span style={{
        position: 'absolute', top: 1, left: on ? 18 : 1,
        width: 18, height: 18, borderRadius: '50%',
        background: '#fff',
        border: '1.5px solid var(--border-ink)',
        transition: 'left var(--dur-base) var(--ease-spring)',
      }}/>
    </button>
  );
}

// ============ ProjectPicker — smart dropdown ============
// No horizontal scroll. Tap header to expand inline list with search.
// Scales cleanly from 3 projects to 30.
function ProjectPicker({ project, setProject, projectOptions, isOpen, setOpen }) {
  const [query, setQuery] = useState('');
  const current = projectOptions.find(p => p.id === project) || projectOptions[0];

  const filtered = query.trim()
    ? projectOptions.filter(p => p.name.toLowerCase().includes(query.toLowerCase()))
    : projectOptions;

  return (
    <div style={{
      background: 'var(--bg-elevated)',
      border: '2px solid ' + (isOpen ? 'var(--border-ink)' : 'var(--border)'),
      borderRadius: 'var(--r-lg)',
      marginTop: 12,
      overflow: 'hidden',
      transition: 'border-color var(--dur-fast) var(--ease-out)',
      boxShadow: isOpen ? 'var(--shadow-pop)' : 'none',
    }}>
      {/* Header — tap to toggle */}
      <button
        onClick={() => { setOpen(!isOpen); setQuery(''); }}
        style={{
          display: 'flex', alignItems: 'center', gap: 10, width: '100%',
          padding: 14, background: 'transparent', border: 'none', cursor: 'pointer',
          textAlign: 'left',
        }}
      >
        <Icon name="folder-open" size={18} color="var(--fg2)"/>
        <div style={{
          fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600,
          color: 'var(--fg1)', flex: 1,
        }}>
          Project
        </div>
        {/* Current selection chip */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px 4px 4px',
          background: 'var(--bg-sunken)',
          border: '1.5px solid var(--border)',
          borderRadius: 'var(--r-full)',
          minWidth: 0,
        }}>
          <span style={{
            width: 18, height: 18, borderRadius: '50%',
            background: current.color,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 10, flexShrink: 0,
          }}>{current.emoji}</span>
          <span style={{
            fontFamily: 'var(--font-sans)', fontSize: 13, fontWeight: 500,
            color: 'var(--fg1)',
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 120,
          }}>{current.name}</span>
        </div>
        <Icon
          name="chevron-down"
          size={16}
          color="var(--fg3)"
          style={{
            transition: 'transform var(--dur-base) var(--ease-spring)',
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
            flexShrink: 0,
          }}
        />
      </button>

      {/* Expanded list */}
      {isOpen && (
        <div style={{
          borderTop: '1.5px solid var(--border)',
          padding: '10px 10px 10px',
          animation: 'ploot-fade-in 180ms var(--ease-out) both',
        }}>
          {/* Search */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '8px 12px',
            background: 'var(--bg-sunken)',
            border: '1.5px solid var(--border)',
            borderRadius: 'var(--r-md)',
            marginBottom: 8,
          }}>
            <Icon name="search" size={14} color="var(--fg3)"/>
            <input
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Search or type to create"
              style={{
                flex: 1, border: 'none', outline: 'none', background: 'transparent',
                fontFamily: 'var(--font-sans)', fontSize: 13, color: 'var(--fg1)',
              }}
            />
          </div>

          {/* List of projects — vertical, never overflows */}
          <div style={{
            display: 'flex', flexDirection: 'column', gap: 2,
            maxHeight: 220, overflowY: 'auto', overflowX: 'hidden',
          }}>
            {filtered.map(p => {
              const active = project === p.id;
              return (
                <button
                  key={p.id}
                  onClick={() => { setProject(p.id); setOpen(false); setQuery(''); }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 10,
                    padding: '10px 12px',
                    background: active ? 'var(--ploot-clay-100)' : 'transparent',
                    border: 'none',
                    borderRadius: 'var(--r-sm)',
                    cursor: 'pointer',
                    textAlign: 'left',
                    width: '100%',
                    transition: 'background var(--dur-fast) var(--ease-out)',
                  }}
                >
                  <span style={{
                    width: 26, height: 26, borderRadius: 8,
                    background: p.color,
                    border: '1.5px solid var(--border-ink)',
                    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 13, flexShrink: 0,
                  }}>{p.emoji}</span>
                  <span style={{
                    flex: 1, minWidth: 0,
                    fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: active ? 600 : 500,
                    color: active ? 'var(--ploot-clay-700)' : 'var(--fg1)',
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>{p.name}</span>
                  {active && <Icon name="check" size={16} color="var(--ploot-clay-700)"/>}
                </button>
              );
            })}

            {/* "Create new project" action when no match */}
            {filtered.length === 0 && query.trim() && (
              <button
                onClick={() => setOpen(false)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  padding: '10px 12px',
                  background: 'var(--bg-sunken)',
                  border: '1.5px dashed var(--border-strong)',
                  borderRadius: 'var(--r-sm)',
                  cursor: 'pointer', textAlign: 'left',
                  fontFamily: 'var(--font-sans)', fontSize: 13, color: 'var(--fg2)',
                }}
              >
                <Icon name="plus" size={14}/>
                <span>Create "<span style={{ color: 'var(--fg1)', fontWeight: 600 }}>{query}</span>"</span>
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function QuickAction({ icon, label }) {
  return (
    <button style={{
      flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
      padding: '10px 8px',
      background: 'var(--bg-elevated)',
      border: '2px dashed var(--border)',
      borderRadius: 'var(--r-md)',
      color: 'var(--fg2)', cursor: 'pointer',
      transition: 'all var(--dur-fast) var(--ease-out)',
    }}>
      <Icon name={icon} size={16}/>
      <span style={{ fontFamily: 'var(--font-sans)', fontSize: 11, fontWeight: 600 }}>{label}</span>
    </button>
  );
}

function CalendarScreen({ tasks }) {
  const [selected, setSelected] = useState(new Date().getDate());
  const today = new Date();
  const days = [];
  for (let i = -2; i < 26; i++) {
    const d = new Date(today);
    d.setDate(today.getDate() + i);
    days.push(d);
  }
  const dayTasks = tasks.filter(t => t.section === 'today').slice(0, 4);
  return (
    <ScreenFrame title="Calendar" subtitle="Plan the shape of your week.">
      {/* Horizontal day picker */}
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '6px 16px 18px', scrollbarWidth: 'none' }}>
        {days.map((d, i) => {
          const isSelected = d.getDate() === selected && d.getMonth() === today.getMonth();
          const isToday = d.toDateString() === today.toDateString();
          return (
            <button
              key={i}
              onClick={() => setSelected(d.getDate())}
              style={{
                minWidth: 52, padding: '10px 8px',
                borderRadius: 14,
                background: isSelected ? 'var(--primary)' : 'var(--bg-elevated)',
                color: isSelected ? 'var(--on-primary)' : 'var(--fg1)',
                border: '2px solid ' + (isSelected ? 'var(--border-ink)' : 'var(--border)'),
                boxShadow: isSelected ? 'var(--shadow-pop)' : 'none',
                cursor: 'pointer',
                display: 'flex', flexDirection: 'column', gap: 2, alignItems: 'center',
                transform: isSelected ? 'translateY(-2px)' : 'none',
                transition: 'all var(--dur-fast) var(--ease-spring)',
                flexShrink: 0,
              }}
            >
              <span style={{ fontSize: 10, fontFamily: 'var(--font-mono)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em', opacity: 0.8 }}>
                {d.toLocaleDateString('en-US', { weekday: 'short' }).slice(0,3)}
              </span>
              <span style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600, lineHeight: 1 }}>{d.getDate()}</span>
              {isToday && <span style={{ width: 4, height: 4, borderRadius: '50%', background: isSelected ? 'var(--on-primary)' : 'var(--primary)' }}/>}
            </button>
          );
        })}
      </div>

      {/* Timed blocks */}
      <div style={{ padding: '0 16px 120px' }}>
        {['8 AM','10 AM','12 PM','2 PM','4 PM'].map((time, i) => (
          <div key={time} style={{ display: 'flex', gap: 14, marginBottom: 8, minHeight: 48 }}>
            <div style={{ width: 48, fontSize: 11, color: 'var(--fg3)', fontFamily: 'var(--font-mono)', fontWeight: 500, paddingTop: 6 }}>{time}</div>
            <div style={{ flex: 1, borderTop: '1px dashed var(--border)', paddingTop: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
              {dayTasks[i] && (
                <Card padding={10} interactive style={{
                  background: i === 0 ? 'var(--ploot-clay-100)' : i === 1 ? 'var(--ploot-forest-100)' : i === 2 ? 'var(--ploot-butter-100)' : 'var(--ploot-sky-100)',
                }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--fg1)' }}>{dayTasks[i].title}</div>
                  <div style={{ fontSize: 12, color: 'var(--fg2)', marginTop: 2 }}>{dayTasks[i].duration || '30 min'}</div>
                </Card>
              )}
            </div>
          </div>
        ))}
      </div>
    </ScreenFrame>
  );
}

function DoneScreen({ tasks }) {
  const doneTasks = tasks.filter(t => t.done);
  const streak = 7;
  return (
    <ScreenFrame title="Done" subtitle={`${doneTasks.length} this week. Look at you go.`}>
      <div style={{ padding: '4px 16px 16px' }}>
        <Card padding={18} style={{ background: 'var(--primary)', color: 'var(--on-primary)' }}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
            <div style={{ fontSize: 48 }}>🔥</div>
            <div>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 34, fontWeight: 600, lineHeight: 1 }}>{streak}</div>
              <div style={{ fontSize: 13, fontWeight: 500, opacity: 0.9 }}>day streak · don't break it</div>
            </div>
          </div>
        </Card>
      </div>

      {/* Weekly stats */}
      <div style={{ padding: '0 16px 8px', display: 'flex', gap: 8 }}>
        {[3,5,2,7,4,6,doneTasks.length || 1].map((n, i) => {
          const labels = ['M','T','W','T','F','S','S'];
          const today = i === 6;
          return (
            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={{
                width: '100%', height: n * 10 + 12, borderRadius: 8,
                background: today ? 'var(--primary)' : 'var(--ploot-clay-200)',
                border: '2px solid var(--border-ink)',
              }}/>
              <span style={{ fontSize: 11, fontFamily: 'var(--font-mono)', color: today ? 'var(--fg1)' : 'var(--fg3)', fontWeight: today ? 700 : 500 }}>{labels[i]}</span>
            </div>
          );
        })}
      </div>

      <SectionHeader title="Recently crushed" count={doneTasks.length} />
      {doneTasks.length > 0
        ? doneTasks.map(t => <TaskRow key={t.id} task={t} onToggle={() => {}} />)
        : <Empty illustration="../../assets/illo-inbox-zero.svg" title="Nothing yet." subtitle="Check something off — any task counts." />
      }
      <div style={{ height: 120 }}/>
    </ScreenFrame>
  );
}

Object.assign(window, { TodayScreen, ProjectsScreen, TaskDetailScreen, QuickAddSheet, CalendarScreen, DoneScreen });
