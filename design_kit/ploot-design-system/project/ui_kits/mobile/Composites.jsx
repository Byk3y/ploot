// Ploot mobile — composite components

const { useState: useStateTR } = React;

// ============ TaskRow — the key component ============
function TaskRow({ task, onToggle, onOpen }) {
  const [justCompleted, setJustCompleted] = useState(false);
  const priorityColors = { low: 'var(--fg3)', normal: 'var(--fg3)', medium: 'var(--ploot-butter-500)', high: 'var(--ploot-plum-500)', urgent: 'var(--primary)' };
  const projectColors = { 'work': 'var(--ploot-sky-500)', 'home': 'var(--ploot-forest-500)', 'side': 'var(--ploot-plum-500)', 'errands': 'var(--ploot-butter-500)', 'inbox': 'var(--fg3)' };
  function handleToggle(val) {
    if (val) {
      setJustCompleted(true);
      setTimeout(() => { setJustCompleted(false); onToggle && onToggle(val); }, 350);
    } else onToggle && onToggle(val);
  }
  return (
    <div
      onClick={() => onOpen && onOpen(task)}
      style={{
        display: 'flex', gap: 12, padding: '14px 16px', alignItems: 'flex-start',
        background: 'var(--bg-elevated)',
        borderBottom: '1px solid var(--border)',
        cursor: 'pointer',
        opacity: justCompleted ? 0.4 : 1,
        transition: 'opacity 300ms var(--ease-out)',
      }}
    >
      <div onClick={e => e.stopPropagation()} style={{ paddingTop: 1 }}>
        <Checkbox checked={task.done} onChange={handleToggle} priority={task.priority} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 15, fontWeight: 500, color: 'var(--fg1)',
          textDecoration: task.done ? 'line-through' : 'none',
          opacity: task.done ? 0.5 : 1,
          letterSpacing: '-0.005em',
        }}>{task.title}</div>
        {(task.due || task.project || (task.tags && task.tags.length) || task.note) && (
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6, alignItems: 'center' }}>
            {task.due && (
              <span style={{ fontSize: 12, color: task.overdue ? 'var(--danger)' : 'var(--fg2)', fontWeight: 500, display: 'inline-flex', gap: 3, alignItems: 'center' }}>
                <Icon name="calendar" size={12}/> {task.due}
              </span>
            )}
            {task.project && (
              <span style={{ fontSize: 12, color: 'var(--fg2)', display: 'inline-flex', gap: 4, alignItems: 'center' }}>
                <span style={{ width: 6, height: 6, borderRadius: '50%', background: projectColors[task.project] || 'var(--fg3)' }} />
                {task.project[0].toUpperCase() + task.project.slice(1)}
              </span>
            )}
            {task.tags && task.tags.map(t => <Chip key={t} color="ink">{t}</Chip>)}
          </div>
        )}
      </div>
      {task.priority === 'urgent' && !task.done && (
        <span style={{ fontSize: 14, color: 'var(--primary)' }}>🔥</span>
      )}
    </div>
  );
}

// ============ ScreenFrame — device frame with title header ============
function ScreenFrame({ title, subtitle, children, rightAction, leftAction, transparent }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', height: '100%',
      background: transparent ? 'transparent' : 'var(--bg)',
    }}>
      {(title || leftAction || rightAction) && (
        <header style={{
          display: 'flex', alignItems: 'center', padding: '12px 16px 8px',
          gap: 12, minHeight: 56,
        }}>
          {leftAction}
          <div style={{ flex: 1, minWidth: 0 }}>
            {title && <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, letterSpacing: '-0.015em', color: 'var(--fg1)' }}>{title}</div>}
            {subtitle && <div style={{ fontSize: 13, color: 'var(--fg3)', marginTop: 2 }}>{subtitle}</div>}
          </div>
          {rightAction}
        </header>
      )}
      <div style={{ flex: 1, overflow: 'auto', minHeight: 0 }}>{children}</div>
    </div>
  );
}

// ============ TabBar — bottom navigation ============
function TabBar({ current, onChange }) {
  const tabs = [
    { id: 'today',    icon: 'sun',         label: 'Today' },
    { id: 'projects', icon: 'folder-open', label: 'Projects' },
    { id: 'calendar', icon: 'calendar',    label: 'Calendar' },
    { id: 'done',     icon: 'check-circle',label: 'Done' },
  ];
  return (
    <nav style={{
      display: 'flex', background: 'var(--bg-elevated)',
      borderTop: '2px solid var(--border-ink)',
      padding: '8px 8px 24px',
      position: 'relative',
    }}>
      {tabs.map(t => {
        const active = current === t.id;
        return (
          <button
            key={t.id}
            onClick={() => onChange && onChange(t.id)}
            style={{
              flex: 1, display: 'flex', flexDirection: 'column', gap: 2,
              alignItems: 'center', padding: '8px 4px',
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: active ? 'var(--primary)' : 'var(--fg3)',
              transition: 'color var(--dur-fast)',
              position: 'relative',
            }}
          >
            <div style={{
              transition: 'transform 260ms var(--ease-spring)',
              transform: active ? 'scale(1.1) translateY(-1px)' : 'scale(1)',
            }}>
              <Icon name={t.icon} size={22} stroke={active ? 2.5 : 2}/>
            </div>
            <span style={{ fontSize: 11, fontWeight: active ? 700 : 500 }}>{t.label}</span>
          </button>
        );
      })}
    </nav>
  );
}

// ============ FAB — floating add button ============
function FAB({ onClick, icon = 'plus' }) {
  const [pressed, setPressed] = useState(false);
  return (
    <button
      onClick={onClick}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{
        position: 'absolute', right: 20, bottom: 92,
        width: 60, height: 60, borderRadius: '50%',
        background: 'var(--primary)', color: 'var(--on-primary)',
        border: '2.5px solid var(--border-ink)',
        boxShadow: pressed ? '0 0 0 var(--border-ink)' : 'var(--shadow-pop-lg)',
        transform: pressed ? 'translateY(4px)' : 'translateY(0)',
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        transition: 'all var(--dur-fast) var(--ease-spring)',
        zIndex: 10,
      }}
    >
      <Icon name={icon} size={28} stroke={2.5}/>
    </button>
  );
}

// ============ Section header ============
function SectionHeader({ title, count, action }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 8,
      padding: '20px 16px 10px', position: 'sticky', top: 0,
      background: 'var(--bg)', zIndex: 1,
    }}>
      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.08em', fontWeight: 600, color: 'var(--fg2)' }}>{title}</span>
      {count != null && (
        <span style={{
          fontSize: 11, fontWeight: 700, fontFamily: 'var(--font-mono)',
          padding: '1px 7px', borderRadius: 'var(--r-full)',
          background: 'var(--bg-sunken)', color: 'var(--fg2)',
        }}>{count}</span>
      )}
      {action && <div style={{ marginLeft: 'auto' }}>{action}</div>}
    </div>
  );
}

// ============ Empty state ============
function Empty({ illustration, title, subtitle, action }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      justifyContent: 'center', padding: '48px 24px', gap: 12,
      textAlign: 'center', height: '100%',
    }}>
      {illustration && <img src={illustration} alt="" style={{ width: 140, height: 140 }} />}
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 24, fontWeight: 600, letterSpacing: '-0.015em', color: 'var(--fg1)', marginTop: 4 }}>{title}</div>
      {subtitle && <div style={{ fontSize: 14, color: 'var(--fg2)', maxWidth: 260, lineHeight: 1.5 }}>{subtitle}</div>}
      {action}
    </div>
  );
}

Object.assign(window, { TaskRow, ScreenFrame, TabBar, FAB, SectionHeader, Empty });
