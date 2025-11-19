
/** Simple localStorage-backed witness log for demo purposes (Phase 2). */
const WITNESS_KEY = "adtech_witnessed_topics";
const TOPICS_LOG_KEY = "adtech_topics_log";

export function recordWitness(topicName) {
  try {
    const set = new Set(JSON.parse(localStorage.getItem(WITNESS_KEY) || "[]"));
    set.add(topicName);
    localStorage.setItem(WITNESS_KEY, JSON.stringify([...set]));
  } catch {}
}

export function getWitnesses() {
  try {
    return new Set(JSON.parse(localStorage.getItem(WITNESS_KEY) || "[]"));
  } catch { return new Set(); }
}

export function clearWitnesses() {
  localStorage.removeItem(WITNESS_KEY);
}

export function logTopics(source, topics) {
  try {
    const now = new Date().toISOString();
    const entries = JSON.parse(localStorage.getItem(TOPICS_LOG_KEY) || "[]");
    entries.push({ ts: now, source, topics });
    localStorage.setItem(TOPICS_LOG_KEY, JSON.stringify(entries));
  } catch {}
}

export function getTopicLog() {
  try {
    return JSON.parse(localStorage.getItem(TOPICS_LOG_KEY) || "[]");
  } catch { return []; }
}

export function clearTopicLog() {
  localStorage.removeItem(TOPICS_LOG_KEY);
}
