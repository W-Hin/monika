-- Training catalogue seed: 34 programmes (17 open to browse, 17 reachable
-- only as recommendations), each with 3 lessons and a 5-question quiz.
--
-- Run AFTER migrations 0038 (lessons/quizzes) and 0039 (access rules).
-- Safe to re-run: a programme is only inserted if no programme with that
-- title exists, and lessons/questions are only added to a programme that
-- has none yet — so it never overwrites edits HR has made in the app.
--
-- How the recommendation-only half is reached:
--   * trigger_risk_level / trigger_attendance_below  -> fired automatically by
--     refresh_training_recommendations_for() from risk classification or
--     90-day attendance (remedial programmes).
--   * neither trigger set -> reached through a Performance Evaluation: a KPI
--     scored below its category threshold recommends the first eligible
--     programme in that category (PeController / TrainingService.recommendForCategory).
--   * min_tenure_months keeps advanced programmes locked until the employee
--     has served long enough.

-- ── Cybersecurity Essentials ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Cybersecurity Essentials', 'technical', 'The everyday habits that keep company and personal data safe: strong passwords, spotting phishing, and handling suspicious activity.', true, '2 hours · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Cybersecurity Essentials');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Why attackers target employees', 'Most breaches start with a person, not a machine. Attackers send convincing emails or messages hoping someone will click a link, open an attachment or hand over a password. Staff are the first line of defence because they see these attempts before any software does.'),
  (2, 'Passwords and multi-factor authentication', 'Use a long, unique passphrase for every account and a password manager to remember them. Turn on multi-factor authentication wherever it is offered, so a stolen password alone is not enough to get in. Never share a password, even with a colleague or IT support.'),
  (3, 'Spotting and reporting phishing', 'Check the sender address, hover over links before clicking, and be suspicious of urgency such as "act now or your account closes". Unexpected attachments and requests for credentials or payments are red flags. If in doubt, do not click: report it to IT and delete it.')
) as v(sort_order, title, body)
where p.title = 'Cybersecurity Essentials' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which is the strongest password choice?', array['Password123', 'Your birthday', 'A long unique passphrase', 'The same password as your email']::text[], 2, 'Length and uniqueness matter most; reuse lets one breach unlock many accounts.'),
  (2, 'What does multi-factor authentication add?', array['A faster login', 'A second proof of identity beyond the password', 'A longer password', 'Automatic password changes']::text[], 1, 'A second factor means a stolen password alone is not enough.'),
  (3, 'You receive an unexpected email asking you to urgently confirm your login. What should you do?', array['Click the link quickly', 'Reply with your password', 'Report it to IT without clicking', 'Forward it to colleagues']::text[], 2, 'Urgency and credential requests are classic phishing signs.'),
  (4, 'Is it acceptable to share your password with a trusted colleague?', array['Yes, if they are senior', 'Yes, for urgent work', 'No, never', 'Only over the phone']::text[], 2, 'Credentials are personal; shared passwords destroy accountability.'),
  (5, 'What should you check before clicking a link in an email?', array['The font used', 'Where the link really goes', 'The email length', 'The time it was sent']::text[], 1, 'Hovering reveals the real destination, which often differs from the text.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Cybersecurity Essentials' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Data Privacy & PDPA Basics ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Data Privacy & PDPA Basics', 'technical', 'What personal data is, how Malaysia''s PDPA expects it to be handled, and the day-to-day rules for collecting, storing and sharing it.', true, '90 minutes · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Data Privacy & PDPA Basics');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'What counts as personal data', 'Personal data is any information that can identify a person: names, ID numbers, contact details, photos, salary records and attendance logs. Even a combination of harmless details can identify someone. If you can tell who it is about, treat it as personal data.'),
  (2, 'The core PDPA principles', 'Collect only what you need and tell people why. Use the data only for the purpose you stated, keep it accurate, and do not keep it longer than necessary. Protect it with sensible security and let individuals see and correct their own data.'),
  (3, 'Everyday handling rules', 'Share personal data only with people who need it to do their job. Do not leave printouts on desks or send records to personal email. Report any loss or wrongful disclosure straight away so it can be contained.')
) as v(sort_order, title, body)
where p.title = 'Data Privacy & PDPA Basics' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which of these is personal data?', array['A public holiday list', 'An employee''s ID number', 'The office address', 'A product price list']::text[], 1, 'An ID number identifies a specific person.'),
  (2, 'You may use data you collected for payroll to...', array['Send marketing emails', 'Process payroll', 'Share with any friend', 'Post online']::text[], 1, 'Data must be used for the purpose it was collected for.'),
  (3, 'How long should personal data be kept?', array['Forever', 'Only as long as necessary', 'Until the employee asks', 'One week']::text[], 1, 'Keeping data longer than needed increases risk.'),
  (4, 'Who should have access to employee salary records?', array['Everyone in the company', 'Only those who need it for their role', 'Any manager', 'Interns']::text[], 1, 'Access follows need-to-know.'),
  (5, 'You notice a file of employee records was sent to the wrong person. First step?', array['Ignore it', 'Delete your email', 'Report it immediately', 'Wait to see if they notice']::text[], 2, 'Prompt reporting lets the incident be contained.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Data Privacy & PDPA Basics' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Excel for Everyday Work ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Excel for Everyday Work', 'technical', 'Practical spreadsheet skills: formulas, sorting and filtering, and tidy data habits that save hours every week.', false, '3 hours · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Excel for Everyday Work');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Cells, formulas and references', 'A formula starts with = and can add, subtract or call functions such as SUM and AVERAGE. A relative reference like A1 changes when copied; an absolute reference like $A$1 stays fixed. Use fixed references for values such as a tax rate that every row must share.'),
  (2, 'Sorting, filtering and tables', 'Convert your range to a table so filters and formulas expand automatically. Sort to rank rows and filter to focus on what matters, without deleting anything. Keep one record per row and one fact per column.'),
  (3, 'Lookups and clean data', 'XLOOKUP or VLOOKUP pulls a matching value from another table, which is how you join lists without retyping. Remove stray spaces, keep dates as real dates and avoid merged cells, because they break sorting and formulas.')
) as v(sort_order, title, body)
where p.title = 'Excel for Everyday Work' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which symbol starts every Excel formula?', array['#', '=', '@', '?']::text[], 1, 'Formulas always begin with an equals sign.'),
  (2, 'What does $A$1 mean?', array['A cell that changes when copied', 'A fixed reference that does not change', 'A currency cell', 'A merged cell']::text[], 1, 'Dollar signs lock the row and column.'),
  (3, 'Which function adds a range of numbers?', array['COUNT', 'SUM', 'LOOKUP', 'ROUND']::text[], 1, 'SUM totals the values in a range.'),
  (4, 'Why avoid merged cells in data tables?', array['They look bad', 'They break sorting and formulas', 'They use more memory', 'They are not allowed']::text[], 1, 'Merged cells disrupt the grid that sorting relies on.'),
  (5, 'Which tool finds a matching value in another table?', array['SORT', 'XLOOKUP', 'PASTE', 'FILL']::text[], 1, 'XLOOKUP/VLOOKUP join data from different tables.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Excel for Everyday Work' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Introduction to Cloud Computing ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Introduction to Cloud Computing', 'technical', 'What "the cloud" really is, the main service models, and how teams decide what to run where.', false, '2 hours · Self-paced', (select id from public.departments where name = 'Engineering'), 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Introduction to Cloud Computing');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'From servers to services', 'Cloud computing means renting computing resources over the internet instead of owning hardware. You pay for what you use and can scale up or down within minutes. This turns large upfront costs into flexible running costs.'),
  (2, 'IaaS, PaaS and SaaS', 'Infrastructure as a service gives you raw virtual machines and storage. Platform as a service adds a managed runtime so you only deploy code. Software as a service delivers a finished application, such as email or HR software, through a browser.'),
  (3, 'Shared responsibility', 'The provider secures the data centre and hardware; you secure your data, accounts and configuration. Most cloud breaches come from misconfiguration, such as a storage bucket left public, not from the provider being hacked.')
) as v(sort_order, title, body)
where p.title = 'Introduction to Cloud Computing' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'What is the main idea of cloud computing?', array['Buying more servers', 'Renting computing resources over the internet', 'Storing files on USB drives', 'Using only local software']::text[], 1, 'Resources are consumed as a service.'),
  (2, 'Which model gives you a finished application in a browser?', array['IaaS', 'PaaS', 'SaaS', 'On-premise']::text[], 2, 'SaaS delivers complete software.'),
  (3, 'Under shared responsibility, who secures your account configuration?', array['The provider only', 'You', 'Nobody', 'The government']::text[], 1, 'Customers configure and protect their own data and access.'),
  (4, 'A common cause of cloud data leaks is...', array['Weather', 'Misconfigured storage', 'Slow internet', 'Too many users']::text[], 1, 'Publicly exposed storage is a frequent mistake.'),
  (5, 'A benefit of the cloud is...', array['Fixed costs only', 'Scaling up or down on demand', 'No need for security', 'Zero maintenance of your data']::text[], 1, 'Elastic scaling is a core advantage.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Introduction to Cloud Computing' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Git & Version Control Basics ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Git & Version Control Basics', 'technical', 'Track changes, collaborate safely and recover from mistakes using Git.', false, '2 hours · Self-paced', (select id from public.departments where name = 'Engineering'), 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Git & Version Control Basics');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Why version control', 'Version control records every change to your files so you can see what changed, who changed it and why, and go back if something breaks. It also lets many people work on the same project without overwriting each other.'),
  (2, 'Commits, branches and merging', 'A commit is a saved snapshot with a message explaining it. A branch is an independent line of work, so features can be built without disturbing the main code. When the work is ready it is merged back, and conflicts are resolved by choosing what to keep.'),
  (3, 'Good habits', 'Commit small, related changes with clear messages. Pull the latest changes before you start and never commit secrets such as passwords or API keys. Review a diff before committing so nothing unintended slips in.')
) as v(sort_order, title, body)
where p.title = 'Git & Version Control Basics' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'What is a commit?', array['A deleted file', 'A saved snapshot of changes', 'A server', 'A branch name']::text[], 1, 'Commits record changes with a message.'),
  (2, 'Why use a branch?', array['To delete history', 'To work on a feature without disturbing main code', 'To speed up the computer', 'To hide files']::text[], 1, 'Branches isolate work in progress.'),
  (3, 'Which should you never commit?', array['Source code', 'Documentation', 'Passwords and API keys', 'Tests']::text[], 2, 'Secrets in history are hard to remove and easy to leak.'),
  (4, 'A merge conflict happens when...', array['Two changes touch the same lines', 'Git is out of date', 'A file is too large', 'The network is down']::text[], 0, 'Git cannot decide automatically between overlapping edits.'),
  (5, 'What makes a good commit message?', array['"stuff"', 'A clear description of the change', 'Your name only', 'Nothing']::text[], 1, 'Messages help future readers understand why.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Git & Version Control Basics' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Digital Marketing Fundamentals ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Digital Marketing Fundamentals', 'technical', 'How online channels work together: search, social, email and content, and how to measure what works.', false, '3 hours · Self-paced', (select id from public.departments where name = 'Marketing'), 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Digital Marketing Fundamentals');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'The digital marketing funnel', 'Customers move from awareness to consideration to decision. Different channels suit different stages: content and social build awareness, email and retargeting nurture interest, and offers close the sale. Match the message to where the customer is.'),
  (2, 'Search, social and email', 'Search engine optimisation earns free visibility for what people are already looking for. Social media builds relationships and reach, while email reaches people who already opted in and usually gives the best return when the list is healthy.'),
  (3, 'Measuring results', 'Track a few meaningful numbers: reach, click-through rate, conversion rate and cost per acquisition. Test one change at a time so you know what caused a result. A campaign without a measurable goal cannot be judged.')
) as v(sort_order, title, body)
where p.title = 'Digital Marketing Fundamentals' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which stage comes first in the funnel?', array['Decision', 'Awareness', 'Loyalty', 'Refund']::text[], 1, 'People must know you exist before considering you.'),
  (2, 'Email is often effective because...', array['Everyone reads spam', 'Recipients opted in', 'It is free of rules', 'It needs no content']::text[], 1, 'Opt-in audiences are already interested.'),
  (3, 'What does conversion rate measure?', array['Page colour', 'Share of visitors who take the desired action', 'Number of posts', 'Website speed']::text[], 1, 'It shows how many visitors complete the goal.'),
  (4, 'Why change only one thing in a test?', array['It is cheaper', 'To know what caused the difference', 'Rules require it', 'It is faster']::text[], 1, 'Single-variable tests give clear cause and effect.'),
  (5, 'SEO mainly aims to...', array['Buy ads', 'Earn organic search visibility', 'Send email', 'Design logos']::text[], 1, 'SEO improves unpaid search ranking.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Digital Marketing Fundamentals' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Workplace Communication Skills ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Workplace Communication Skills', 'behavioural', 'Speak, write and listen clearly so that messages are understood the first time.', false, '2 hours · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Workplace Communication Skills');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Clear writing', 'Lead with the point, then give the detail. Short sentences and plain words beat jargon. In emails, put the action you need and the deadline near the top so the reader does not have to hunt for it.'),
  (2, 'Active listening', 'Give the speaker your full attention, avoid planning your reply while they talk, and check understanding by paraphrasing: "So you need the report by Friday?" Questions show interest and prevent costly misunderstandings.'),
  (3, 'Choosing the right channel', 'Use chat for quick questions, email for decisions that need a record, and a call or meeting for anything sensitive or complicated. Tone is easily lost in text, so when a thread gets heated, pick up the phone.')
) as v(sort_order, title, body)
where p.title = 'Workplace Communication Skills' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Where should the key request go in an email?', array['The last line', 'Near the top', 'In the signature', 'Hidden in an attachment']::text[], 1, 'Readers skim; put the action first.'),
  (2, 'Paraphrasing helps because it...', array['Wastes time', 'Confirms you understood', 'Ends the call', 'Hides mistakes']::text[], 1, 'Repeating back catches misunderstandings.'),
  (3, 'Best channel for a sensitive discussion?', array['Group chat', 'A call or private conversation', 'Social media', 'Email to everyone']::text[], 1, 'Sensitive topics need tone and privacy.'),
  (4, 'Which writing style is best?', array['Long and technical', 'Short and plain', 'Full of jargon', 'All capitals']::text[], 1, 'Plain language is understood faster.'),
  (5, 'When is it better to call instead of chat?', array['Never', 'When a thread becomes heated or complex', 'Only on Fridays', 'When you are bored']::text[], 1, 'Voice reduces misreading of tone.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Workplace Communication Skills' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Time Management Essentials ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Time Management Essentials', 'behavioural', 'Plan your day, protect focus time and stop deadlines from sneaking up on you.', false, '2 hours · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Time Management Essentials');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Priorities first', 'Separate what is urgent from what is important. Important work that is not yet urgent, such as planning or learning, is what gets squeezed out. Choose your top three tasks each morning and do the hardest one first.'),
  (2, 'Planning and time blocking', 'Put tasks into your calendar as blocks, not just a to-do list. Add a buffer because tasks usually take longer than expected. Group similar tasks such as emails to avoid constant switching.'),
  (3, 'Protecting focus', 'Silence notifications during focus blocks and check messages at set times. Say no, or negotiate a later date, when a new request would break an existing commitment. Review at the end of the day and carry forward only what matters.')
) as v(sort_order, title, body)
where p.title = 'Time Management Essentials' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which tasks usually get squeezed out?', array['Urgent ones', 'Important but not urgent ones', 'Trivial ones', 'Social ones']::text[], 1, 'Important work lacks a deadline pressure.'),
  (2, 'Why add buffer time?', array['To look busy', 'Tasks often overrun', 'Rules require it', 'To finish early always']::text[], 1, 'Estimates are usually optimistic.'),
  (3, 'Time blocking means...', array['Skipping breaks', 'Scheduling tasks as calendar blocks', 'Working overtime', 'Blocking colleagues']::text[], 1, 'Blocks turn intentions into commitments.'),
  (4, 'A good way to handle a new request that clashes with your plan?', array['Accept silently', 'Negotiate a later date', 'Ignore it', 'Work all night']::text[], 1, 'Renegotiate rather than overload yourself.'),
  (5, 'Checking messages only at set times helps...', array['Slow replies forever', 'Protect focus', 'Hide from work', 'Reduce pay']::text[], 1, 'Fewer interruptions mean deeper work.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Time Management Essentials' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Teamwork & Collaboration ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Teamwork & Collaboration', 'behavioural', 'How good teams share work, give credit and resolve friction before it grows.', false, '2 hours · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Teamwork & Collaboration');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Shared goals and clear roles', 'Teams struggle when people are unsure who owns what. Agree the goal, split the work, and state who decides. Clear roles remove duplicated effort and stop tasks falling between chairs.'),
  (2, 'Trust and credit', 'Do what you say you will, and say early when you cannot. Give credit publicly and raise problems privately first. Trust grows when people see you act consistently, especially under pressure.'),
  (3, 'Disagreeing well', 'Challenge the idea, not the person. Ask questions to understand the other view before defending yours. Once a decision is made, support it even if it was not your first choice.')
) as v(sort_order, title, body)
where p.title = 'Teamwork & Collaboration' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'What causes duplicated effort in teams?', array['Too much trust', 'Unclear roles', 'Short meetings', 'Good planning']::text[], 1, 'Without ownership, people overlap or miss tasks.'),
  (2, 'If you cannot meet a commitment, you should...', array['Say nothing', 'Tell the team early', 'Blame others', 'Wait until the deadline']::text[], 1, 'Early warning lets others adjust.'),
  (3, 'Disagreeing well means challenging...', array['The person', 'The idea', 'The manager', 'Nobody']::text[], 1, 'Critique ideas, not people.'),
  (4, 'After a decision is made you should...', array['Quietly resist', 'Support it', 'Reopen it daily', 'Ignore it']::text[], 1, 'Teams need aligned action after debate.'),
  (5, 'Where should you praise good work?', array['Only in private', 'Publicly where appropriate', 'Never', 'Only to your friends']::text[], 1, 'Public credit builds morale.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Teamwork & Collaboration' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Workplace Safety & Wellbeing ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Workplace Safety & Wellbeing', 'behavioural', 'Everyone''s role in a safe workplace: hazards, emergencies, ergonomics and looking after your own health.', true, '90 minutes · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Workplace Safety & Wellbeing');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Spotting and reporting hazards', 'Wet floors, trailing cables, blocked exits and faulty equipment cause most office injuries. If you see a hazard, make it safe if you can do so without risk, and report it. A near miss reported today prevents an injury tomorrow.'),
  (2, 'Emergencies', 'Know where the fire exits, assembly point and first-aid kit are. On an alarm, leave calmly by the nearest safe exit, do not use lifts, and do not go back for belongings. Follow the warden''s instructions and report to the assembly point.'),
  (3, 'Ergonomics and wellbeing', 'Sit with feet flat, screen at eye level and wrists neutral. Take short breaks to stand and stretch. Persistent stress, poor sleep or low mood are health issues too, so use support channels early rather than waiting until it is serious.')
) as v(sort_order, title, body)
where p.title = 'Workplace Safety & Wellbeing' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'What should you do on a fire alarm?', array['Use the lift', 'Leave by the nearest safe exit', 'Collect your belongings first', 'Keep working']::text[], 1, 'Lifts are unsafe in a fire; leave promptly.'),
  (2, 'A near miss should be...', array['Ignored', 'Reported', 'Hidden', 'Celebrated']::text[], 1, 'Reporting prevents real injuries.'),
  (3, 'Where should your screen sit?', array['Below your lap', 'At eye level', 'Behind you', 'Above your head']::text[], 1, 'Eye-level screens reduce neck strain.'),
  (4, 'Why take short breaks?', array['To avoid work', 'Reduce strain and fatigue', 'Rules only', 'To socialise only']::text[], 1, 'Movement protects posture and focus.'),
  (5, 'When should you seek wellbeing support?', array['Only in a crisis', 'Early, when problems start', 'Never', 'After leaving the job']::text[], 1, 'Early help is more effective.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Workplace Safety & Wellbeing' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Customer Service Excellence ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Customer Service Excellence', 'behavioural', 'Handle enquiries and complaints in a way that keeps customers and protects the company''s reputation.', false, '2 hours · Self-paced', (select id from public.departments where name = 'Sales'), 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Customer Service Excellence');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Understanding the customer', 'Listen to the whole problem before offering a solution, and confirm what you heard. Customers want to feel understood first; a quick answer to the wrong question frustrates them more than a short wait.'),
  (2, 'Handling complaints', 'Stay calm, acknowledge the frustration and apologise for the experience without admitting fault you are not sure about. Explain what you will do and by when, then actually do it. Following up after resolution turns many complainers into loyal customers.'),
  (3, 'Setting honest expectations', 'Never promise what you cannot deliver. A realistic timeline that you meet builds more trust than a fast one you miss. If something changes, tell the customer before they have to ask.')
) as v(sort_order, title, body)
where p.title = 'Customer Service Excellence' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'What should you do first with an upset customer?', array['Explain policy', 'Listen to the whole problem', 'Transfer them', 'End the call']::text[], 1, 'Listening de-escalates and clarifies.'),
  (2, 'A good complaint response includes...', array['Blame', 'Acknowledgement and a clear next step', 'Silence', 'Excuses']::text[], 1, 'Customers need to see action.'),
  (3, 'Why set honest timelines?', array['To look slow', 'Missed promises damage trust', 'Rules forbid speed', 'Customers prefer delays']::text[], 1, 'Reliability builds trust.'),
  (4, 'If a delivery date changes, you should...', array['Wait for them to ask', 'Tell them proactively', 'Hide it', 'Cancel the order']::text[], 1, 'Proactive updates keep trust.'),
  (5, 'Following up after a fix...', array['Is wasteful', 'Shows care and builds loyalty', 'Annoys customers', 'Is illegal']::text[], 1, 'Follow-up confirms the issue is truly resolved.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Customer Service Excellence' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Professional Workplace Etiquette ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Professional Workplace Etiquette', 'behavioural', 'The unwritten rules that help new joiners and interns fit in quickly and be taken seriously.', false, '90 minutes · Self-paced', null, 'open', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Professional Workplace Etiquette');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'First impressions', 'Arrive a few minutes early, greet people and learn names. Dress to the workplace''s standard and keep your phone away in meetings. Small courtesies are noticed more than you think.'),
  (2, 'Asking for help', 'Try for a reasonable time first, then ask a specific question with what you have already tried. Write down answers so you do not ask the same thing twice. Asking is expected; guessing silently is the real risk.'),
  (3, 'Reliability and communication', 'Reply to messages within a sensible time, meet deadlines or flag problems early, and keep your manager informed. Being dependable in small things is how you get trusted with larger ones.')
) as v(sort_order, title, body)
where p.title = 'Professional Workplace Etiquette' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'How early should you aim to arrive?', array['After start time', 'A few minutes early', 'Exactly late', 'An hour late']::text[], 1, 'Being early signals reliability.'),
  (2, 'Before asking for help you should...', array['Never try', 'Try first and note what you tried', 'Wait a week', 'Ask everyone']::text[], 1, 'Specific questions get faster answers.'),
  (3, 'Phones in meetings should be...', array['On the table', 'Put away', 'On loudspeaker', 'Used for games']::text[], 1, 'Attention shows respect.'),
  (4, 'If you will miss a deadline you should...', array['Stay silent', 'Flag it early', 'Blame others', 'Submit blank work']::text[], 1, 'Early warning maintains trust.'),
  (5, 'Dependability in small tasks leads to...', array['Nothing', 'More trust and responsibility', 'Less work', 'Pay cuts']::text[], 1, 'Trust is earned through consistency.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Professional Workplace Etiquette' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Introduction to Leadership ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Introduction to Leadership', 'leadership', 'What changes when you start leading others, and the core habits of effective team leaders.', false, '3 hours · Self-paced', null, 'open', 12, null, null
where not exists (select 1 from public.training_programs where title = 'Introduction to Leadership');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'From doer to leader', 'Your success shifts from how much you produce to how well your team performs. That means delegating, teaching and removing obstacles rather than doing everything yourself. Many new leaders struggle because they keep doing the old job.'),
  (2, 'Setting direction', 'Explain the goal and why it matters, then let people decide how. Clear expectations, regular check-ins and honest feedback give people what they need to succeed without being micromanaged.'),
  (3, 'Leading by example', 'Teams copy what leaders do, not what they say. Keep your commitments, admit mistakes quickly and treat everyone with respect, especially when under pressure.')
) as v(sort_order, title, body)
where p.title = 'Introduction to Leadership' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'A new leader''s success is measured mostly by...', array['Personal output', 'Team performance', 'Hours worked', 'Meetings attended']::text[], 1, 'Leadership multiplies through others.'),
  (2, 'Good delegation includes...', array['Explaining goal and why', 'Giving no information', 'Checking every minute', 'Doing it yourself']::text[], 0, 'People need context to own a task.'),
  (3, 'Teams tend to copy...', array['Policies', 'Leaders'' behaviour', 'Posters', 'Email footers']::text[], 1, 'Behaviour sets the culture.'),
  (4, 'Micromanaging typically...', array['Builds trust', 'Reduces ownership and morale', 'Improves speed', 'Is recommended']::text[], 1, 'People disengage when over-controlled.'),
  (5, 'When you make a mistake as a leader you should...', array['Hide it', 'Admit it quickly', 'Blame the team', 'Ignore it']::text[], 1, 'Owning errors builds credibility.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Introduction to Leadership' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Giving and Receiving Feedback ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Giving and Receiving Feedback', 'leadership', 'Turn feedback into a normal, useful part of work rather than something people dread.', false, '2 hours · Self-paced', null, 'open', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Giving and Receiving Feedback');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Feedback that works', 'Be specific, timely and about behaviour rather than character. Describe what you saw, the effect it had and what you would like next time. "Your report was late and held up the client call" is useful; "you are unreliable" is not.'),
  (2, 'Receiving feedback', 'Listen without defending, ask clarifying questions and thank the person. You do not have to agree immediately, but take time to consider it. Defensive reactions teach people to stop telling you things.'),
  (3, 'Making it routine', 'Short, frequent feedback beats an annual surprise. Mix recognition with improvement points, and follow up later to acknowledge progress.')
) as v(sort_order, title, body)
where p.title = 'Giving and Receiving Feedback' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Good feedback focuses on...', array['Personality', 'Specific behaviour and its effect', 'Rumours', 'Appearance']::text[], 1, 'Behaviour can be changed; labels cannot.'),
  (2, 'When receiving feedback first...', array['Argue', 'Listen and clarify', 'Leave', 'Counter-attack']::text[], 1, 'Understanding comes before response.'),
  (3, 'Which is better timing?', array['Long after the event', 'Soon after the event', 'Never', 'Only annually']::text[], 1, 'Timely feedback is easier to act on.'),
  (4, 'Why follow up after giving feedback?', array['To nag', 'To acknowledge progress', 'To punish', 'It is unnecessary']::text[], 1, 'Follow-up reinforces change.'),
  (5, 'Defensive reactions cause people to...', array['Give more feedback', 'Stop being honest with you', 'Praise you', 'Work harder']::text[], 1, 'People avoid risky honesty.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Giving and Receiving Feedback' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Running Effective Meetings ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Running Effective Meetings', 'leadership', 'Make meetings shorter, clearer and worth everyone''s time.', false, '90 minutes · Self-paced', null, 'open', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Running Effective Meetings');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Before the meeting', 'Decide whether a meeting is needed at all. If so, set a purpose, invite only who is necessary and share an agenda in advance. A meeting with no desired outcome is just a conversation that costs everyone time.'),
  (2, 'During the meeting', 'Start on time, follow the agenda and keep discussion on topic. Make sure quieter people are heard, and capture decisions and action items as you go, each with an owner and a date.'),
  (3, 'After the meeting', 'Send notes within a day listing decisions and who does what by when. Then check progress at the next touchpoint. Actions without owners tend to disappear.')
) as v(sort_order, title, body)
where p.title = 'Running Effective Meetings' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'First question before calling a meeting?', array['Who brings snacks', 'Is a meeting needed?', 'Which room', 'What to wear']::text[], 1, 'Many meetings can be an email.'),
  (2, 'An agenda should be shared...', array['After the meeting', 'In advance', 'Never', 'During lunch']::text[], 1, 'Preparation improves quality.'),
  (3, 'Each action item needs...', array['An owner and a date', 'A long title', 'A joke', 'Nothing']::text[], 0, 'Accountability needs names and dates.'),
  (4, 'Notes should be sent...', array['Next year', 'Within a day', 'Never', 'Verbally only']::text[], 1, 'Quick notes keep momentum.'),
  (5, 'Who should be invited?', array['Everyone', 'Only those needed', 'Only managers', 'Nobody']::text[], 1, 'Unnecessary attendees waste time.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Running Effective Meetings' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Coaching & Mentoring Juniors ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Coaching & Mentoring Juniors', 'leadership', 'Help newer colleagues and interns grow faster through questions, feedback and stretch tasks.', false, '2 hours · Self-paced', null, 'open', 12, null, null
where not exists (select 1 from public.training_programs where title = 'Coaching & Mentoring Juniors');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Coaching vs telling', 'Telling gives the answer; coaching helps the person find it. Ask open questions such as "What have you tried?" and "What would you do next?" People remember conclusions they reached themselves.'),
  (2, 'Setting up the relationship', 'Agree what the person wants to learn, how often you will meet and how you prefer to communicate. Regular short sessions work better than occasional long ones.'),
  (3, 'Stretch and support', 'Give tasks slightly beyond current ability, with a safety net. Celebrate progress, discuss what went wrong without blame and gradually reduce your involvement as confidence grows.')
) as v(sort_order, title, body)
where p.title = 'Coaching & Mentoring Juniors' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Coaching differs from telling because it...', array['Gives answers', 'Helps people find answers', 'Avoids feedback', 'Is shorter']::text[], 1, 'Coaches build capability.'),
  (2, 'A good coaching question is...', array['"Why did you fail?"', '"What would you try next?"', '"Do it my way."', '"Never mind."']::text[], 1, 'Open questions provoke thinking.'),
  (3, 'Better mentoring rhythm?', array['Rare long sessions', 'Regular short sessions', 'Never', 'Only at reviews']::text[], 1, 'Consistency builds momentum.'),
  (4, 'A stretch task should be...', array['Impossible', 'Slightly beyond current ability with support', 'Trivial', 'Secret']::text[], 1, 'Growth happens at the edge of ability.'),
  (5, 'When something goes wrong you should...', array['Blame', 'Explore lessons without blame', 'Hide it', 'Take over permanently']::text[], 1, 'Blameless review sustains learning.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Coaching & Mentoring Juniors' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Project Management Basics ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Project Management Basics', 'leadership', 'Plan, track and deliver small projects on time with a simple, repeatable approach.', false, '3 hours · Self-paced', null, 'open', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Project Management Basics');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Defining the project', 'State the goal, scope and what "done" means. List what is in and out of scope, because unmanaged scope growth is the most common reason projects slip. Identify the stakeholders who must be kept informed.'),
  (2, 'Planning the work', 'Break the goal into tasks, estimate each, and find dependencies. Add buffer to the schedule and identify the biggest risks early with a plan for each. A visible plan lets everyone see what is happening.'),
  (3, 'Tracking and communicating', 'Review progress regularly against the plan, surface problems early and report simply: what is done, what is next, what is blocked. Close the project by capturing lessons learned.')
) as v(sort_order, title, body)
where p.title = 'Project Management Basics' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'The most common cause of project delays is...', array['Scope creep', 'Good planning', 'Clear goals', 'Regular reviews']::text[], 0, 'Uncontrolled scope growth is the classic culprit.'),
  (2, 'Defining "done" helps because...', array['It adds paperwork', 'Everyone knows the finish line', 'It slows work', 'It is optional']::text[], 1, 'A shared finish line prevents disputes.'),
  (3, 'Why add schedule buffer?', array['Estimates are uncertain', 'To slow the team', 'Rules', 'To impress']::text[], 0, 'Things rarely go exactly to plan.'),
  (4, 'A status report should say...', array['Nothing', 'Done, next and blocked', 'Only good news', 'Only bad news']::text[], 1, 'Simple, honest status builds trust.'),
  (5, 'At project close you should...', array['Delete everything', 'Capture lessons learned', 'Start another immediately', 'Ignore feedback']::text[], 1, 'Lessons improve the next project.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Project Management Basics' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Insider Threats & Data Misuse ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Insider Threats & Data Misuse', 'technical', 'How trusted access can be abused or exploited, the warning signs, and the responsibilities that come with access.', false, '90 minutes · Self-paced', null, 'recommended_only', 0, 'high', null
where not exists (select 1 from public.training_programs where title = 'Insider Threats & Data Misuse');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'What an insider threat is', 'An insider threat is risk that comes from someone with legitimate access: a careless employee, one who is manipulated by an outsider, or one who deliberately misuses access. Most are accidental, but all can cause serious damage.'),
  (2, 'Warning signs and prevention', 'Unusual access to files outside someone''s role, copying large amounts of data, or bypassing controls are warning signs. Prevention relies on least-privilege access, activity logging and a culture where people report concerns without fear.'),
  (3, 'Your responsibilities', 'Use access only for your job. Never lend credentials, clock in for anyone else or take company data home without approval. If you see something that looks wrong, report it through the proper channel.')
) as v(sort_order, title, body)
where p.title = 'Insider Threats & Data Misuse' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Most insider incidents are...', array['Always deliberate', 'Often accidental', 'Impossible', 'Caused by weather']::text[], 1, 'Careless mistakes are the most common cause.'),
  (2, 'Least-privilege means...', array['Everyone has full access', 'Only the access needed for the role', 'No access', 'Shared logins']::text[], 1, 'Limit access to what the job requires.'),
  (3, 'Is it acceptable to clock in or log in for a colleague?', array['Yes, to help', 'No, it is misuse of access', 'Only on Fridays', 'If they ask nicely']::text[], 1, 'Proxy attendance and shared logins are misuse.'),
  (4, 'Which is a warning sign?', array['Normal work hours', 'Copying large volumes of unrelated data', 'Taking leave', 'Asking questions']::text[], 1, 'Unusual bulk copying is a red flag.'),
  (5, 'If you suspect misuse you should...', array['Confront them angrily', 'Report through the proper channel', 'Ignore it', 'Post online']::text[], 1, 'Formal reporting protects everyone.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Insider Threats & Data Misuse' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Secure Device & Account Use ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Secure Device & Account Use', 'technical', 'Why one person, one device, one account matters, and how to use company devices safely.', false, '60 minutes · Self-paced', null, 'recommended_only', 0, 'medium', null
where not exists (select 1 from public.training_programs where title = 'Secure Device & Account Use');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'One person, one identity', 'Accounts and devices are tied to a single person so that actions can be traced. Sharing them removes accountability and hides who really did something. It also means that if one is compromised, an attacker inherits every privilege.'),
  (2, 'Protecting your device', 'Lock your screen when away, keep software updated and install apps only from trusted sources. Report a lost or stolen device immediately so access can be revoked.'),
  (3, 'Safe networks and public places', 'Avoid sensitive work on open public WiFi, and be careful of screens being read over your shoulder. Use the company VPN where provided.')
) as v(sort_order, title, body)
where p.title = 'Secure Device & Account Use' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Why are accounts tied to one person?', array['Convenience', 'So actions are traceable', 'Cost', 'Fashion']::text[], 1, 'Traceability depends on unique identities.'),
  (2, 'If your device is lost you should...', array['Wait', 'Report it immediately', 'Buy a new one quietly', 'Tell a friend']::text[], 1, 'Quick revocation limits harm.'),
  (3, 'Public WiFi is risky because...', array['It is slow', 'It may be unsecured', 'It is free', 'It is popular']::text[], 1, 'Others on the network may intercept traffic.'),
  (4, 'When leaving your desk you should...', array['Leave it unlocked', 'Lock your screen', 'Turn up volume', 'Share your login']::text[], 1, 'Locking prevents casual misuse.'),
  (5, 'Software updates are important because they...', array['Add decoration', 'Fix security flaws', 'Slow devices', 'Delete files']::text[], 1, 'Patches close known vulnerabilities.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Secure Device & Account Use' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Advanced Excel & Data Analysis ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Advanced Excel & Data Analysis', 'technical', 'Pivot tables, charts and data cleaning for people who already know the basics.', false, '4 hours · Self-paced', null, 'recommended_only', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Advanced Excel & Data Analysis');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Pivot tables', 'A pivot table summarises thousands of rows into a compact report by dragging fields into rows, columns and values. Change the grouping in seconds to answer new questions without rewriting formulas.'),
  (2, 'Charts that communicate', 'Choose the chart to match the question: lines for trends, bars for comparisons, and avoid 3D effects or too many colours. Label axes and give the chart a title that states the message.'),
  (3, 'Cleaning and validating data', 'Use data validation to restrict entries, remove duplicates deliberately, and check totals against a known source. Trustworthy analysis begins with clean input.')
) as v(sort_order, title, body)
where p.title = 'Advanced Excel & Data Analysis' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'A pivot table is used to...', array['Summarise large data quickly', 'Spell check', 'Print labels', 'Lock files']::text[], 0, 'Pivots aggregate rows into reports.'),
  (2, 'Which chart best shows a trend over time?', array['Pie', 'Line', 'Scatter of colours', '3D cone']::text[], 1, 'Lines show change over time.'),
  (3, 'Data validation helps by...', array['Restricting entries to valid values', 'Deleting data', 'Hiding sheets', 'Adding colours']::text[], 0, 'It prevents bad input.'),
  (4, 'Before trusting a total you should...', array['Assume it is right', 'Check it against a known source', 'Delete the sheet', 'Round everything']::text[], 1, 'Reconcile with a control figure.'),
  (5, 'A good chart title should...', array['Be blank', 'State the message', 'Be decorative', 'Be in capitals only']::text[], 1, 'The title should tell the reader the takeaway.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Advanced Excel & Data Analysis' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Software Testing & Quality Basics ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Software Testing & Quality Basics', 'technical', 'Why testing matters and how to write simple tests that catch bugs before users do.', false, '3 hours · Self-paced', (select id from public.departments where name = 'Engineering'), 'recommended_only', 3, null, null
where not exists (select 1 from public.training_programs where title = 'Software Testing & Quality Basics');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Why we test', 'Bugs found early cost far less to fix than bugs found by customers. Tests also act as living documentation and give confidence to change code without breaking it.'),
  (2, 'Kinds of tests', 'Unit tests check small pieces in isolation, integration tests check that parts work together, and end-to-end tests walk through a real user journey. Have many fast unit tests and fewer slow end-to-end ones.'),
  (3, 'Writing a good test', 'Test one behaviour at a time, name the test after what it checks, and cover the edge cases such as empty input, limits and failures. A test that never fails is not protecting you.')
) as v(sort_order, title, body)
where p.title = 'Software Testing & Quality Basics' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Bugs are cheapest to fix when found...', array['By customers', 'Early in development', 'After release', 'Never']::text[], 1, 'Early detection limits cost.'),
  (2, 'Which tests check small pieces in isolation?', array['Unit tests', 'End-to-end tests', 'Load tests', 'Demos']::text[], 0, 'Unit tests isolate units of code.'),
  (3, 'A good test checks...', array['Many things at once', 'One behaviour', 'Nothing', 'Only happy paths']::text[], 1, 'Focused tests are easier to diagnose.'),
  (4, 'Edge cases include...', array['Empty input and limits', 'Only typical values', 'Colours', 'Nothing']::text[], 0, 'Bugs hide at the boundaries.'),
  (5, 'Why name tests clearly?', array['Fashion', 'They describe expected behaviour', 'Rules', 'No reason']::text[], 1, 'Names act as documentation.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Software Testing & Quality Basics' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Financial Reporting Fundamentals ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Financial Reporting Fundamentals', 'technical', 'Read and prepare the core financial statements and understand how transactions flow into them.', false, '3 hours · Self-paced', (select id from public.departments where name = 'Finance'), 'recommended_only', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Financial Reporting Fundamentals');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'The three statements', 'The income statement shows profit over a period, the balance sheet shows what the company owns and owes at a point in time, and the cash flow statement shows where cash came from and went. They are linked, so a change in one affects the others.'),
  (2, 'Double-entry in brief', 'Every transaction is recorded twice, as a debit in one account and a credit in another, so the books always balance. This catches many errors and creates an audit trail.'),
  (3, 'Accuracy and cut-off', 'Record income and expenses in the period they belong to, not when cash moves. Reconcile accounts regularly and keep supporting documents for every entry.')
) as v(sort_order, title, body)
where p.title = 'Financial Reporting Fundamentals' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Which statement shows profit over a period?', array['Balance sheet', 'Income statement', 'Cash flow only', 'Budget']::text[], 1, 'The income statement reports profit or loss.'),
  (2, 'In double-entry, every transaction is recorded...', array['Once', 'Twice, as debit and credit', 'Never', 'In cash only']::text[], 1, 'Debits equal credits.'),
  (3, 'The balance sheet shows...', array['Profit for the year', 'Assets and liabilities at a point in time', 'Only cash', 'Sales targets']::text[], 1, 'It is a snapshot.'),
  (4, 'Why keep supporting documents?', array['Clutter', 'Evidence for audit', 'Tradition', 'No reason']::text[], 1, 'Documents support every entry.'),
  (5, 'Reconciling accounts regularly helps to...', array['Find errors early', 'Add costs', 'Delete records', 'Hide differences']::text[], 0, 'Frequent reconciliation catches mistakes.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Financial Reporting Fundamentals' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Sales Pipeline & CRM Skills ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Sales Pipeline & CRM Skills', 'technical', 'Keep a clean pipeline in the CRM and use it to forecast and prioritise.', false, '2 hours · Self-paced', (select id from public.departments where name = 'Sales'), 'recommended_only', 3, null, null
where not exists (select 1 from public.training_programs where title = 'Sales Pipeline & CRM Skills');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'The pipeline stages', 'A pipeline moves a lead through stages such as qualified, proposal, negotiation and closed. Each stage should have a clear entry rule so everyone means the same thing by "proposal sent".'),
  (2, 'Keeping the CRM useful', 'Update records right after each interaction, log the next step and date, and close lost deals with a reason. A CRM is only as valuable as its data is current.'),
  (3, 'Forecasting and focus', 'Weight deals by stage probability to forecast, and spend your time on the deals most likely to close. Review stalled deals regularly and either move them forward or let them go.')
) as v(sort_order, title, body)
where p.title = 'Sales Pipeline & CRM Skills' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Why define entry rules for stages?', array['Paperwork', 'Everyone uses stages consistently', 'Slowing sales', 'No reason']::text[], 1, 'Shared definitions make reports meaningful.'),
  (2, 'When should you update the CRM?', array['At year end', 'Right after interactions', 'Never', 'When asked']::text[], 1, 'Fresh data is useful data.'),
  (3, 'A closed-lost deal should include...', array['Nothing', 'The reason it was lost', 'A celebration', 'Deletion']::text[], 1, 'Reasons reveal patterns.'),
  (4, 'Forecasts weight deals by...', array['Colour', 'Stage probability', 'Name length', 'Random']::text[], 1, 'Later stages are likelier to close.'),
  (5, 'Stalled deals should be...', array['Ignored forever', 'Reviewed and moved or closed', 'Hidden', 'Duplicated']::text[], 1, 'Regular review keeps the pipeline honest.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Sales Pipeline & CRM Skills' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Punctuality & Reliability Reset ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Punctuality & Reliability Reset', 'behavioural', 'Practical routines to arrive on time, and why consistent timekeeping matters to your team.', false, '60 minutes · Self-paced', null, 'recommended_only', 0, null, 90
where not exists (select 1 from public.training_programs where title = 'Punctuality & Reliability Reset');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Why punctuality matters', 'When one person is late, others wait, meetings start late and customers notice. Consistent arrival is one of the simplest ways to show reliability, and it is usually the first thing managers notice.'),
  (2, 'Finding the real cause', 'Track for a week when you leave and what delays you. Common causes are underestimating travel, a rushed morning and late nights. Fix the cause, not the symptom: prepare things the night before and plan to arrive ten minutes early.'),
  (3, 'Talking to your manager', 'If there is a genuine ongoing barrier such as transport or caring duties, say so early. Managers can often help with flexible arrangements, but only if they know before it becomes a pattern.')
) as v(sort_order, title, body)
where p.title = 'Punctuality & Reliability Reset' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Why does lateness affect others?', array['It does not', 'Others wait and plans shift', 'It speeds meetings', 'It is private']::text[], 1, 'Lateness has knock-on effects.'),
  (2, 'A good first step to improving punctuality?', array['Ignore it', 'Find the real cause', 'Blame traffic', 'Quit']::text[], 1, 'Solve the cause, not the symptom.'),
  (3, 'Planning to arrive early gives...', array['A buffer for delays', 'Less sleep', 'Nothing', 'Higher pay']::text[], 0, 'Buffers absorb surprises.'),
  (4, 'If a barrier is genuine and ongoing you should...', array['Hide it', 'Tell your manager early', 'Be late silently', 'Stop coming']::text[], 1, 'Early disclosure opens options.'),
  (5, 'Reliability is mostly shown by...', array['Words', 'Consistent behaviour', 'Titles', 'Emails']::text[], 1, 'Consistency builds trust.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Punctuality & Reliability Reset' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Attendance Accountability ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Attendance Accountability', 'behavioural', 'What your attendance means for the team and company, and how to plan absences responsibly.', false, '60 minutes · Self-paced', null, 'recommended_only', 0, null, 80
where not exists (select 1 from public.training_programs where title = 'Attendance Accountability');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'The impact of absence', 'Unplanned absence shifts work to colleagues, delays projects and affects payroll accuracy. Everyone has genuine reasons to be away sometimes; what matters is how it is communicated.'),
  (2, 'Planning and reporting', 'Apply for leave in advance whenever possible and report unplanned absence as early as you can, through the proper channel, not through a colleague. Provide a medical certificate where required.'),
  (3, 'Getting back on track', 'If your attendance has dipped, meet your manager to agree a plan. Small commitments you can keep, such as clocking in on time every day this month, rebuild trust quickly.')
) as v(sort_order, title, body)
where p.title = 'Attendance Accountability' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Unplanned absence affects...', array['Nobody', 'Colleagues and projects', 'Only you', 'The weather']::text[], 1, 'Work is redistributed.'),
  (2, 'You should apply for planned leave...', array['After the fact', 'In advance', 'Never', 'On the last day']::text[], 1, 'Advance notice allows cover.'),
  (3, 'Report unplanned absence...', array['As early as possible via the proper channel', 'Next week', 'Through a friend only', 'Never']::text[], 0, 'Early notice enables arrangements.'),
  (4, 'Rebuilding trust works best through...', array['Promises', 'Small commitments you keep', 'Excuses', 'Avoiding the manager']::text[], 1, 'Kept commitments restore trust.'),
  (5, 'A medical certificate is needed...', array['Never', 'Where the policy requires it', 'Always for lunch', 'For holidays']::text[], 1, 'Follow the policy.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Attendance Accountability' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Workplace Integrity & Ethics ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Workplace Integrity & Ethics', 'behavioural', 'Honesty, fairness and doing the right thing when no one is watching.', false, '90 minutes · Self-paced', null, 'recommended_only', 0, 'medium', null
where not exists (select 1 from public.training_programs where title = 'Workplace Integrity & Ethics');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'What integrity looks like', 'Integrity means being honest in reports, expenses and attendance, and keeping to the rules even when shortcuts are tempting. It is about consistent behaviour, not just avoiding trouble.'),
  (2, 'Common grey areas', 'Rounding up your hours, clocking in from the wrong place, accepting expensive gifts or using company resources privately can feel minor but are policy breaches. If you are unsure, ask before acting.'),
  (3, 'Speaking up', 'Raise concerns with your manager or HR, and expect to be protected from retaliation when you do so in good faith. Silence allows small problems to become serious ones.')
) as v(sort_order, title, body)
where p.title = 'Workplace Integrity & Ethics' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Integrity means being honest...', array['Only when watched', 'Even when no one is watching', 'Never', 'Sometimes']::text[], 1, 'Consistency defines integrity.'),
  (2, 'Clocking in from the wrong location is...', array['Fine', 'A policy breach', 'Encouraged', 'Invisible']::text[], 1, 'Attendance records must be truthful.'),
  (3, 'If unsure whether something is allowed you should...', array['Guess', 'Ask first', 'Do it quietly', 'Ignore policy']::text[], 1, 'Asking prevents breaches.'),
  (4, 'Good-faith reporters are...', array['Punished', 'Protected from retaliation', 'Ignored', 'Fined']::text[], 1, 'Protection encourages speaking up.'),
  (5, 'Silence about small problems can...', array['Fix them', 'Let them grow', 'Remove them', 'Make them legal']::text[], 1, 'Small issues escalate.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Workplace Integrity & Ethics' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Professional Conduct Recovery Plan ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Professional Conduct Recovery Plan', 'behavioural', 'A structured plan for employees who have had repeated policy issues to reset expectations and rebuild standing.', false, '2 hours · Self-paced', null, 'recommended_only', 0, 'high', null
where not exists (select 1 from public.training_programs where title = 'Professional Conduct Recovery Plan');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Where things stand', 'Repeated policy breaches affect trust, and the company is required to respond consistently. This programme is a chance to understand what went wrong and agree a clear way forward rather than a punishment.'),
  (2, 'Understanding the rules and why they exist', 'Attendance location checks, one-device-per-person and honest records protect fairness for everyone, including honest colleagues. Knowing the reason behind a rule makes it easier to follow.'),
  (3, 'Your recovery plan', 'Agree specific, measurable commitments with your manager for the next two months, for example zero late arrivals and every clock-in verified. Meet regularly, report honestly on progress and ask for help early if it slips.')
) as v(sort_order, title, body)
where p.title = 'Professional Conduct Recovery Plan' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'The purpose of this programme is to...', array['Humiliate', 'Reset expectations and agree a way forward', 'Fire you', 'Waste time']::text[], 1, 'It is a corrective, supportive step.'),
  (2, 'Rules like location checks exist to...', array['Annoy staff', 'Keep things fair for everyone', 'Cut pay', 'Track hobbies']::text[], 1, 'Fairness for honest employees.'),
  (3, 'A good recovery commitment is...', array['Vague', 'Specific and measurable', 'Secret', 'Impossible']::text[], 1, 'Measurable goals can be tracked.'),
  (4, 'If your plan starts to slip you should...', array['Hide it', 'Ask for help early', 'Give up', 'Blame others']::text[], 1, 'Early help prevents setbacks.'),
  (5, 'Trust is rebuilt mainly by...', array['Time and consistent behaviour', 'Apologies alone', 'Gifts', 'Avoidance']::text[], 0, 'Consistent behaviour over time.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Professional Conduct Recovery Plan' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Stress & Resilience at Work ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Stress & Resilience at Work', 'behavioural', 'Recognise stress early and build habits that keep you effective under pressure.', false, '90 minutes · Self-paced', null, 'recommended_only', 0, null, null
where not exists (select 1 from public.training_programs where title = 'Stress & Resilience at Work');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Recognising stress', 'Early signs include poor sleep, irritability, constant tiredness and dreading work. Stress is a normal response, but when it is constant it harms health and performance. Noticing it early makes it easier to manage.'),
  (2, 'Practical habits', 'Break big tasks into steps, take real breaks, move your body and protect sleep. Separate work from rest by setting a clear end to your day. Small daily habits work better than occasional big fixes.'),
  (3, 'Asking for support', 'Talking to a manager, colleague or HR is a strength, not a weakness. Workload can often be adjusted, and professional support may be available through the company.')
) as v(sort_order, title, body)
where p.title = 'Stress & Resilience at Work' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'An early sign of stress is...', array['Great energy', 'Poor sleep and irritability', 'Bonus pay', 'Free time']::text[], 1, 'Physical and mood changes show strain.'),
  (2, 'Helpful habits include...', array['Skipping breaks', 'Breaks, movement and sleep', 'Overtime nightly', 'Caffeine only']::text[], 1, 'Recovery habits sustain performance.'),
  (3, 'Asking for support is...', array['Weakness', 'A sensible step', 'Forbidden', 'Pointless']::text[], 1, 'Support is available to use.'),
  (4, 'Breaking a task into steps helps by...', array['Making it worse', 'Making it manageable', 'Adding paperwork', 'Delaying it forever']::text[], 1, 'Small steps reduce overwhelm.'),
  (5, 'Setting an end to your workday helps...', array['Nothing', 'Separate work from rest', 'Reduce pay', 'Cancel meetings']::text[], 1, 'Boundaries protect recovery.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Stress & Resilience at Work' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Conflict Resolution ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Conflict Resolution', 'behavioural', 'Handle disagreements early and constructively before they damage working relationships.', false, '2 hours · Self-paced', null, 'recommended_only', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Conflict Resolution');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Why conflict happens', 'Conflict usually comes from unclear expectations, different priorities or communication breakdowns, not from bad people. Understanding the cause is the first step to fixing it.'),
  (2, 'A simple approach', 'Speak privately and soon, describe the issue without blame using "I" statements, then listen to the other view. Look for the interests behind each position and for options that serve both.'),
  (3, 'When to escalate', 'If direct conversation does not work, or the behaviour is harassment or bullying, involve your manager or HR. Keep notes of facts: dates, what was said and the effect.')
) as v(sort_order, title, body)
where p.title = 'Conflict Resolution' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Conflict usually arises from...', array['Bad people only', 'Unclear expectations and communication gaps', 'The weather', 'Pay day']::text[], 1, 'Root causes are often structural.'),
  (2, 'A good opening is...', array['"You always..."', '"I noticed... and it affects..."', 'Shouting', 'Silence']::text[], 1, 'I-statements reduce defensiveness.'),
  (3, 'Where should you first raise a disagreement?', array['In a public chat', 'Privately and soon', 'Never', 'On social media']::text[], 1, 'Private conversations are safest.'),
  (4, 'Harassment or bullying should be...', array['Tolerated', 'Escalated to manager or HR', 'Joked about', 'Ignored']::text[], 1, 'These need formal handling.'),
  (5, 'Why keep factual notes?', array['Gossip', 'Clear evidence if needed', 'Fun', 'No reason']::text[], 1, 'Facts support fair resolution.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Conflict Resolution' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Emotional Intelligence at Work ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Emotional Intelligence at Work', 'behavioural', 'Understand your own reactions and read others better to work more effectively together.', false, '2 hours · Self-paced', null, 'recommended_only', 6, null, null
where not exists (select 1 from public.training_programs where title = 'Emotional Intelligence at Work');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Self-awareness', 'Notice what triggers strong reactions in you and how they show up. Pausing before responding gives you a choice about how to act instead of being driven by the moment.'),
  (2, 'Empathy', 'Try to understand what the other person is feeling and why, even if you disagree. Asking "what is going on for you?" often reveals the real issue behind an irritable message.'),
  (3, 'Managing relationships', 'Adjust your style to the person and situation, give recognition generously and handle difficult messages with care. Emotional intelligence is a skill that improves with practice.')
) as v(sort_order, title, body)
where p.title = 'Emotional Intelligence at Work' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Pausing before reacting gives you...', array['A longer day', 'A choice in your response', 'Nothing', 'Less pay']::text[], 1, 'A pause enables deliberate action.'),
  (2, 'Empathy means...', array['Agreeing with everyone', 'Understanding how others feel', 'Ignoring emotions', 'Avoiding people']::text[], 1, 'It is understanding, not agreement.'),
  (3, 'Self-awareness starts with...', array['Noticing your triggers', 'Blaming others', 'Avoiding feedback', 'Working harder']::text[], 0, 'Know yourself to manage yourself.'),
  (4, 'Emotional intelligence can be...', array['Learned and practised', 'Fixed at birth', 'Bought', 'Irrelevant']::text[], 0, 'It is a skill.'),
  (5, 'A useful question to a frustrated colleague?', array['"Calm down."', '"What is going on for you?"', '"Not my problem."', '"Whatever."']::text[], 1, 'Curiosity opens up the real issue.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Emotional Intelligence at Work' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Leading Without Authority ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Leading Without Authority', 'leadership', 'Influence outcomes and bring people with you when you have no formal power over them.', false, '2 hours · Self-paced', null, 'recommended_only', 12, null, null
where not exists (select 1 from public.training_programs where title = 'Leading Without Authority');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Influence versus authority', 'You can lead without a title by building credibility, being useful and linking what you want to what others care about. People follow those they trust and who help them succeed.'),
  (2, 'Building support', 'Talk to key people one-to-one before a meeting, listen to their concerns and adjust your proposal. Show evidence, offer to do the first step and give credit generously.'),
  (3, 'Sustaining momentum', 'Follow up on commitments, share small wins and keep stakeholders informed. Leadership without authority depends on consistent follow-through.')
) as v(sort_order, title, body)
where p.title = 'Leading Without Authority' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Leading without a title relies mainly on...', array['Threats', 'Credibility and usefulness', 'Rank', 'Volume']::text[], 1, 'Influence is earned.'),
  (2, 'Before a big meeting it helps to...', array['Surprise everyone', 'Speak to key people beforehand', 'Say nothing', 'Cancel it']::text[], 1, 'Pre-alignment reduces resistance.'),
  (3, 'Giving credit generously...', array['Weakens you', 'Builds goodwill', 'Is pointless', 'Is forbidden']::text[], 1, 'Credit earns support.'),
  (4, 'Momentum is kept by...', array['Follow-through', 'Silence', 'Delays', 'Blame']::text[], 0, 'Doing what you say sustains trust.'),
  (5, 'People follow leaders who...', array['Help them succeed', 'Demand obedience', 'Hide information', 'Avoid people']::text[], 0, 'Help builds followership.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Leading Without Authority' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Strategic Thinking for Team Leads ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Strategic Thinking for Team Leads', 'leadership', 'Lift your view from daily tasks to priorities, trade-offs and the longer-term direction of your team.', false, '3 hours · Self-paced', null, 'recommended_only', 24, null, null
where not exists (select 1 from public.training_programs where title = 'Strategic Thinking for Team Leads');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Seeing the bigger picture', 'Strategic thinking asks where the team should be in a year and what matters most to get there. It means stepping back from urgent tasks to ask whether they are the right tasks.'),
  (2, 'Trade-offs and priorities', 'Resources are limited, so choosing something means not choosing something else. Make trade-offs explicit, test them against company goals and explain the reasoning to your team.'),
  (3, 'Turning strategy into action', 'Translate direction into a few clear objectives with owners and measures. Review them regularly and adjust when the situation changes.')
) as v(sort_order, title, body)
where p.title = 'Strategic Thinking for Team Leads' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Strategic thinking asks...', array['What is urgent today only', 'Where should we be in a year', 'Who is late', 'What is for lunch']::text[], 1, 'It is about direction.'),
  (2, 'A trade-off means...', array['Choosing one thing means giving up another', 'Everything is possible', 'Trading shifts', 'Nothing']::text[], 0, 'Limited resources force choices.'),
  (3, 'Priorities should be tested against...', array['Personal preference', 'Company goals', 'Mood', 'Chance']::text[], 1, 'Alignment ensures value.'),
  (4, 'Good objectives have...', array['Owners and measures', 'No detail', 'No owners', 'Secrecy']::text[], 0, 'Accountability needs clarity.'),
  (5, 'Strategy should be reviewed...', array['Never', 'Regularly', 'Once a decade', 'Only by outsiders']::text[], 1, 'Conditions change.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Strategic Thinking for Team Leads' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Managing Performance Conversations ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Managing Performance Conversations', 'leadership', 'Prepare for and hold honest conversations about performance, good and bad.', false, '2 hours · Self-paced', null, 'recommended_only', 18, null, null
where not exists (select 1 from public.training_programs where title = 'Managing Performance Conversations');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Preparing', 'Gather specific examples and facts, decide the outcome you want and think about how the person might react. Choose a private time and avoid delivering a surprise: ongoing feedback should make the conversation unsurprising.'),
  (2, 'Holding the conversation', 'Start with the purpose, describe the facts, ask for their view and listen. Agree specific actions with dates and how progress will be measured. End by confirming what was agreed.'),
  (3, 'Following up', 'Document the agreement, check in at the dates you set and recognise improvement. Consistent follow-up shows the conversation was serious and fair.')
) as v(sort_order, title, body)
where p.title = 'Managing Performance Conversations' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Good preparation includes...', array['Rumours', 'Specific examples and facts', 'Guesswork', 'Nothing']::text[], 1, 'Facts keep it fair.'),
  (2, 'The conversation should end with...', array['Silence', 'Agreed actions and dates', 'An argument', 'A new rule']::text[], 1, 'Agreements need clarity.'),
  (3, 'Ongoing feedback makes the conversation...', array['Harder', 'Less of a surprise', 'Unnecessary', 'Longer']::text[], 1, 'No surprises is the goal.'),
  (4, 'After the conversation you should...', array['Forget it', 'Document and follow up', 'Gossip', 'Repeat it daily']::text[], 1, 'Follow-up shows seriousness.'),
  (5, 'Where should it take place?', array['Public area', 'A private setting', 'Group chat', 'Hallway']::text[], 1, 'Privacy shows respect.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Managing Performance Conversations' and not exists (select 1 from public.training_questions x where x.program_id = p.id);

-- ── Decision Making Under Pressure ──
insert into public.training_programs (title, category, description, is_mandatory, duration, department_id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below)
select 'Decision Making Under Pressure', 'leadership', 'Make timely, sound decisions when information is incomplete and the stakes are high.', false, '2 hours · Self-paced', null, 'recommended_only', 12, null, null
where not exists (select 1 from public.training_programs where title = 'Decision Making Under Pressure');

insert into public.training_lessons (program_id, sort_order, title, body)
select p.id, v.sort_order, v.title, v.body from public.training_programs p
cross join (values
  (1, 'Pressure and judgement', 'Stress narrows attention and pushes us toward quick, familiar answers. Knowing this lets you slow down just enough to ask whether the obvious choice is the right one.'),
  (2, 'A quick decision routine', 'Define the decision, list realistic options, weigh the main risks and benefits and decide who needs to be consulted. If a decision is reversible, move quickly; if it is not, take more care.'),
  (3, 'Owning and learning', 'Decide, communicate clearly and own the result. Afterwards review what you knew then and what you would do differently, without hindsight blame.')
) as v(sort_order, title, body)
where p.title = 'Decision Making Under Pressure' and not exists (select 1 from public.training_lessons l where l.program_id = p.id);

insert into public.training_questions (program_id, sort_order, question, options, correct_index, explanation)
select p.id, v.sort_order, v.question, v.options, v.correct_index, v.explanation from public.training_programs p
cross join (values
  (1, 'Stress tends to...', array['Widen attention', 'Narrow attention', 'Improve memory always', 'Remove risk']::text[], 1, 'Tunnel vision is common under pressure.'),
  (2, 'A reversible decision can be made...', array['More quickly', 'Never', 'Only by committee', 'After a year']::text[], 0, 'Low cost of error allows speed.'),
  (3, 'A quick routine begins by...', array['Defining the decision', 'Panicking', 'Waiting', 'Delegating blame']::text[], 0, 'Clarity first.'),
  (4, 'After deciding, a leader should...', array['Hide', 'Communicate and own the result', 'Blame others', 'Change nothing ever']::text[], 1, 'Ownership builds trust.'),
  (5, 'A fair review looks at...', array['Only the outcome', 'What was known at the time', 'Who to blame', 'Nothing']::text[], 1, 'Judge the decision, not just the result.')
) as v(sort_order, question, options, correct_index, explanation)
where p.title = 'Decision Making Under Pressure' and not exists (select 1 from public.training_questions x where x.program_id = p.id);
