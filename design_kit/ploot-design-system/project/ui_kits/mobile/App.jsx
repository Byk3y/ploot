// Ploot mobile app — demo data and main App component

const initialTasks = [
  { id: 1, title: 'Reply to the one email I\'ve been avoiding', due: 'Today, 2:00 PM', project: 'work', priority: 'urgent', done: false, section: 'today', tags: ['deep work'], note: 'It\'s the one from accounting. You know the one.', overdue: false },
  { id: 2, title: 'Buy more oat milk (again)', due: 'Today', project: 'errands', priority: 'normal', done: false, section: 'today', duration: '15 min' },
  { id: 3, title: 'Outline the Q3 pitch deck', due: 'Today', project: 'work', priority: 'high', done: false, section: 'today', duration: '45 min',
    subtasks: [
      { title: 'Problem statement', done: true },
      { title: 'Market data + chart', done: false },
      { title: 'The funny opening slide', done: false },
    ] },
  { id: 4, title: 'Go for a walk (a real one)', due: 'Today', project: 'home', priority: 'normal', done: true, section: 'today' },
  { id: 5, title: 'Call mom', due: 'Yesterday', project: 'home', priority: 'medium', done: false, section: 'overdue', overdue: true },
  { id: 6, title: 'Water the mysterious plant', due: 'Thu', project: 'home', priority: 'normal', done: false, section: 'later' },
  { id: 7, title: 'Ship v2 of the thing', due: 'Fri', project: 'work', priority: 'high', done: false, section: 'later', tags: ['sprint'] },
  { id: 8, title: 'Pretend to understand the new CSS spec', due: 'Sat', project: 'side', priority: 'normal', done: false, section: 'later' },
  { id: 9, title: 'Morning stretch', done: true, section: 'today', project: 'home', priority: 'normal' },
  { id: 10, title: 'Review PR #1247', done: true, section: 'today', project: 'work', priority: 'normal' },
];

const projects = [
  { id: 'work',    name: 'Work',      emoji: '💼', color: 'var(--ploot-sky-500)',    openCount: 8,  doneCount: 12 },
  { id: 'home',    name: 'Home',      emoji: '🏡', color: 'var(--ploot-forest-500)', openCount: 4,  doneCount: 6 },
  { id: 'side',    name: 'Side quest',emoji: '🚀', color: 'var(--ploot-plum-500)',   openCount: 5,  doneCount: 2 },
  { id: 'errands', name: 'Errands',   emoji: '🛒', color: 'var(--ploot-butter-300)', openCount: 3,  doneCount: 8 },
  { id: 'reading', name: 'Reading',   emoji: '📚', color: 'var(--primary)',          openCount: 12, doneCount: 3 },
];

function PlootApp({ initialTab = 'today', initialAddOpen = false }) {
  const [tab, setTab] = useState(initialTab);
  const [tasks, setTasks] = useState(initialTasks);
  const [openTask, setOpenTask] = useState(null);
  const [addOpen, setAddOpen] = useState(initialAddOpen);

  function toggle(id, val) {
    setTasks(ts => ts.map(t => t.id === id ? { ...t, done: val } : t));
  }

  function addTask({ title, project, priority, due }) {
    setTasks(ts => [{
      id: Date.now(), title, project, priority, due, done: false, section: 'today',
    }, ...ts]);
  }

  let content;
  if (openTask) content = <TaskDetailScreen task={tasks.find(t => t.id === openTask.id)} onBack={() => setOpenTask(null)} onToggle={toggle} />;
  else if (tab === 'today')    content = <TodayScreen tasks={tasks} onToggle={toggle} onOpen={setOpenTask} />;
  else if (tab === 'projects') content = <ProjectsScreen projects={projects} />;
  else if (tab === 'calendar') content = <CalendarScreen tasks={tasks} />;
  else if (tab === 'done')     content = <DoneScreen tasks={tasks} />;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)', position: 'relative', overflow: 'hidden' }}>
      {/* status bar spacer */}
      <div style={{ height: 54, flexShrink: 0 }}/>
      <div style={{ flex: 1, minHeight: 0, position: 'relative', overflow: 'hidden' }}>
        {content}
        {!openTask && <FAB onClick={() => setAddOpen(true)} />}
        {addOpen && <QuickAddSheet onClose={() => setAddOpen(false)} onAdd={addTask} />}
      </div>
      {!openTask && <TabBar current={tab} onChange={setTab} />}
    </div>
  );
}

Object.assign(window, { PlootApp, initialTasks, projects });
