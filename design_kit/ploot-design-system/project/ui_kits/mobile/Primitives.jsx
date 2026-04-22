// Ploot UI Kit — shared component library
// Exports everything to window so other babel scripts can use them.

const { useState, useEffect, useRef } = React;

// ============ Icon component (uses Lucide via CDN) ============
function Icon({ name, size = 20, stroke = 2, color = 'currentColor', style = {}, ...rest }) {
  // Lucide icons are loaded globally; we reference them by name
  const svgRef = useRef(null);
  useEffect(() => {
    if (window.lucide && svgRef.current) {
      window.lucide.createIcons({ icons: window.lucide.icons, nameAttr: 'data-lucide' });
    }
  }, [name]);
  return (
    <i
      ref={svgRef}
      data-lucide={name}
      style={{
        width: size, height: size, display: 'inline-flex',
        alignItems: 'center', justifyContent: 'center',
        color, strokeWidth: stroke, ...style,
      }}
      {...rest}
    />
  );
}

// ============ Button ============
function Button({ variant = 'primary', size = 'md', children, icon, onClick, disabled, fullWidth, style = {}, ...rest }) {
  const sizes = {
    sm: { padding: '6px 12px', fontSize: 13, height: 32, gap: 6, radius: 10 },
    md: { padding: '10px 18px', fontSize: 15, height: 44, gap: 8, radius: 14 },
    lg: { padding: '14px 24px', fontSize: 16, height: 52, gap: 10, radius: 16 },
  };
  const s = sizes[size];
  const variants = {
    primary: {
      background: 'var(--primary)', color: 'var(--on-primary)',
      border: '2px solid var(--border-ink)', boxShadow: 'var(--shadow-pop)',
    },
    secondary: {
      background: 'var(--bg-elevated)', color: 'var(--fg1)',
      border: '2px solid var(--border-ink)', boxShadow: 'var(--shadow-pop)',
    },
    ghost: {
      background: 'transparent', color: 'var(--fg1)',
      border: '2px solid transparent', boxShadow: 'none',
    },
    danger: {
      background: 'var(--danger)', color: '#fff',
      border: '2px solid var(--border-ink)', boxShadow: 'var(--shadow-pop)',
    },
  };
  const v = variants[variant];
  const [pressed, setPressed] = useState(false);
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      style={{
        display: fullWidth ? 'flex' : 'inline-flex', width: fullWidth ? '100%' : 'auto',
        alignItems: 'center', justifyContent: 'center',
        gap: s.gap, padding: s.padding, height: s.height, fontSize: s.fontSize,
        fontFamily: 'var(--font-sans)', fontWeight: 600,
        borderRadius: s.radius, cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        transition: 'transform var(--dur-fast) var(--ease-spring), box-shadow var(--dur-fast) var(--ease-out), background var(--dur-fast)',
        transform: pressed ? 'translate(0, 2px)' : 'translate(0, 0)',
        boxShadow: pressed && v.boxShadow !== 'none' ? '0 0 0 var(--border-ink)' : v.boxShadow,
        letterSpacing: '-0.01em',
        ...v,
        ...style,
      }}
      {...rest}
    >
      {icon && <Icon name={icon} size={size === 'sm' ? 14 : size === 'lg' ? 18 : 16} />}
      {children}
    </button>
  );
}

// ============ Checkbox (the hero interaction — satisfying check) ============
function Checkbox({ checked, onChange, priority = 'normal', size = 24 }) {
  const [bouncing, setBouncing] = useState(false);
  const priorityColors = {
    normal: 'var(--border-strong)',
    medium: 'var(--ploot-butter-500)',
    high: 'var(--ploot-plum-500)',
    urgent: 'var(--primary)',
  };
  const border = priorityColors[priority];
  function handle() {
    if (!checked) {
      setBouncing(true);
      setTimeout(() => setBouncing(false), 500);
    }
    onChange && onChange(!checked);
  }
  return (
    <button
      onClick={handle}
      aria-label="Complete task"
      style={{
        width: size, height: size, minWidth: size,
        border: `2.5px solid ${checked ? 'var(--success)' : border}`,
        borderRadius: '50%',
        background: checked ? 'var(--success)' : 'transparent',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer', padding: 0,
        transition: 'all 220ms var(--ease-spring)',
        transform: bouncing ? 'scale(1.2) rotate(8deg)' : 'scale(1)',
        position: 'relative',
      }}
    >
      {checked && (
        <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none" style={{
          animation: 'ploot-check-draw 260ms var(--ease-spring) forwards',
        }}>
          <path d="M5 12 L10 17 L19 7" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"
            strokeDasharray="24" strokeDashoffset={checked ? 0 : 24}
          />
        </svg>
      )}
      {bouncing && (
        <span style={{
          position: 'absolute', inset: -6, borderRadius: '50%',
          border: '2px solid var(--success)', opacity: 0,
          animation: 'ploot-ring 500ms var(--ease-out) forwards',
        }} />
      )}
    </button>
  );
}

// ============ Tag / Chip ============
function Chip({ children, color = 'ink', icon, onClick, selected }) {
  const palettes = {
    ink:     { bg: 'var(--bg-sunken)',       fg: 'var(--fg2)' },
    clay:    { bg: 'var(--ploot-clay-100)',  fg: 'var(--ploot-clay-700)' },
    forest:  { bg: 'var(--ploot-forest-100)',fg: 'var(--ploot-forest-700)' },
    butter:  { bg: 'var(--ploot-butter-100)',fg: '#7a5a00' },
    plum:    { bg: 'var(--ploot-plum-100)',  fg: 'var(--ploot-plum-500)' },
    sky:     { bg: 'var(--ploot-sky-100)',   fg: 'var(--ploot-sky-500)' },
  };
  const p = palettes[color] || palettes.ink;
  return (
    <span
      onClick={onClick}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 5,
        padding: '4px 10px', borderRadius: 'var(--r-full)',
        background: selected ? 'var(--border-ink)' : p.bg,
        color: selected ? 'var(--fg-inverse)' : p.fg,
        fontSize: 12, fontWeight: 600, fontFamily: 'var(--font-sans)',
        cursor: onClick ? 'pointer' : 'default',
        transition: 'all var(--dur-fast)',
        whiteSpace: 'nowrap',
      }}
    >
      {icon && <Icon name={icon} size={12} />}
      {children}
    </span>
  );
}

// ============ Input field ============
function Field({ label, icon, value, onChange, placeholder, type = 'text', style = {} }) {
  const [focused, setFocused] = useState(false);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {label && <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--fg2)' }}>{label}</span>}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '10px 14px', borderRadius: 14,
        background: 'var(--bg-elevated)',
        border: '2px solid ' + (focused ? 'var(--border-ink)' : 'var(--border)'),
        boxShadow: focused ? 'var(--shadow-pop)' : 'none',
        transition: 'all var(--dur-fast) var(--ease-out)',
        transform: focused ? 'translateY(-1px)' : 'none',
      }}>
        {icon && <Icon name={icon} size={16} color="var(--fg3)" />}
        <input
          type={type} value={value} onChange={e => onChange && onChange(e.target.value)}
          placeholder={placeholder}
          onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
          style={{
            flex: 1, border: 'none', outline: 'none', background: 'transparent',
            fontFamily: 'var(--font-sans)', fontSize: 15, color: 'var(--fg1)',
          }}
        />
      </div>
    </label>
  );
}

// ============ Avatar ============
function Avatar({ initials, size = 32, color = 'var(--ploot-clay-300)' }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: color, color: 'var(--ploot-ink-800)',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 700, fontFamily: 'var(--font-sans)',
      border: '2px solid var(--border-ink)', flexShrink: 0,
    }}>{initials}</div>
  );
}

// ============ Card ============
function Card({ children, style = {}, padding = 16, onClick, interactive }) {
  const [hover, setHover] = useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        background: 'var(--bg-elevated)', padding,
        borderRadius: 'var(--r-lg)',
        border: '2px solid var(--border-ink)',
        boxShadow: interactive && hover ? 'var(--shadow-pop-lg)' : 'var(--shadow-pop)',
        transform: interactive && hover ? 'translateY(-2px)' : 'none',
        transition: 'all var(--dur-fast) var(--ease-spring)',
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
    >{children}</div>
  );
}

Object.assign(window, { Icon, Button, Checkbox, Chip, Field, Avatar, Card });
