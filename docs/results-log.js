export const FORM_URL = 'https://docs.google.com/forms/d/e/1FAIpQLSf6WBi9dpKhygqHkHQ9HmDUY0jUP8zFaloYG-kUrcnBAf_31g/formResponse';

const ENTRY = {
  name: 'entry.1116517870',
  topic: 'entry.1038066343',
  correct: 'entry.738007954',
  total: 'entry.375375561',
  missed: 'entry.784422944'
};

function missedIds(results) {
  return results.filter(r => !r.got_it).map(r => r.question.id).join(',');
}

export function buildLogPayload({ name, topic, results }) {
  const correct = results.filter(r => r.got_it).length;
  return {
    [ENTRY.name]: name,
    [ENTRY.topic]: topic,
    [ENTRY.correct]: String(correct),
    [ENTRY.total]: String(results.length),
    [ENTRY.missed]: missedIds(results)
  };
}

const LOCAL_HOSTS = ['localhost', '127.0.0.1'];

export function shouldLog({ hostname }) {
  return !LOCAL_HOSTS.includes(hostname);
}
