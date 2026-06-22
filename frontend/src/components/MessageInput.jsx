import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import EmojiPicker from 'emoji-picker-react';
import { uploadMedia } from '../api/client';

const ACCEPT = 'image/*,audio/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.txt';

// Small popover for picking a future send time, mirroring ReactionPicker's style.
function SchedulePicker({ onSchedule }) {
    const { t } = useTranslation();
    const [open, setOpen] = useState(false);
    const [when, setWhen] = useState('');

    function submit() {
        if (!when) return;
        onSchedule(new Date(when).toISOString());
        setOpen(false);
        setWhen('');
    }

    return (
        <div className="relative">
            <button
                onClick={() => setOpen(o => !o)}
                title={t('chat.input.scheduleMessage')}
                className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center flex-shrink-0 transition-colors"
            >
                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </button>

            {open && (
                <div className="absolute z-20 bottom-11 right-0 bg-gray-800 border border-gray-600 rounded-xl shadow-lg p-3 w-64">
                    <label className="block text-xs text-gray-400 mb-1">{t('chat.input.sendAt')}</label>
                    <input
                        type="datetime-local"
                        value={when}
                        onChange={e => setWhen(e.target.value)}
                        min={new Date(Date.now() + 60000).toISOString().slice(0, 16)}
                        className="w-full bg-gray-700 border border-gray-600 rounded-lg px-2 py-1.5 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                    <div className="flex gap-2 mt-2">
                        <button onClick={() => setOpen(false)} className="flex-1 py-1.5 rounded-lg bg-gray-700 text-gray-300 hover:bg-gray-600 text-xs">
                            {t('common.cancel')}
                        </button>
                        <button onClick={submit} disabled={!when} className="flex-1 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-40 text-white text-xs font-medium">
                            {t('chat.input.schedule')}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}

function EmojiButton({ onPick }) {
    const { t } = useTranslation();
    const [open, setOpen] = useState(false);

    return (
        <div className="relative">
            <button
                onClick={() => setOpen(o => !o)}
                title={t('chat.input.emojiPicker')}
                className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center flex-shrink-0 transition-colors"
            >
                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M9.172 16.172a4 4 0 005.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </button>

            {open && (
                <div className="absolute z-30 bottom-11 left-0">
                    <EmojiPicker onEmojiClick={d => { onPick(d.emoji); setOpen(false); }} width={300} height={350} />
                </div>
            )}
        </div>
    );
}

function formatRecordTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${String(s).padStart(2, '0')}`;
}

export default function MessageInput({ onSendText, onSendMedia, onSchedule, disabled, replyTarget, onCancelReply, members = [], isGroup }) {
    const { t } = useTranslation();
    const [text, setText]           = useState('');
    const [uploading, setUploading] = useState(false);
    const [progress, setProgress]   = useState(0);
    const [mentionQuery, setMentionQuery] = useState(null); // partial token after '@', or null when not active
    const [recording, setRecording] = useState(false);
    const [recordSeconds, setRecordSeconds] = useState(0);
    const fileRef                   = useRef(null);
    const textareaRef               = useRef(null);
    const mediaRecorderRef          = useRef(null);
    const recordStreamRef           = useRef(null);
    const recordChunksRef           = useRef([]);
    const recordTimerRef            = useRef(null);

    useEffect(() => () => {
        clearInterval(recordTimerRef.current);
        recordStreamRef.current?.getTracks().forEach(tr => tr.stop());
    }, []);

    const mentionCandidates = mentionQuery === null ? [] : [
        ...(isGroup && 'all'.startsWith(mentionQuery.toLowerCase()) ? [{ username: 'all', full_name: t('chat.input.everyoneInGroup') }] : []),
        ...members.filter(m => m.username?.toLowerCase().startsWith(mentionQuery.toLowerCase())),
    ];

    function handleKeyDown(e) {
        if (mentionCandidates.length && e.key === 'Escape') { setMentionQuery(null); return; }
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSendText();
        }
    }

    function handleTextChange(e) {
        const value = e.target.value;
        setText(value);

        const cursor = e.target.selectionStart;
        const upToCursor = value.slice(0, cursor);
        const match = upToCursor.match(/@(\w*)$/);
        setMentionQuery(match ? match[1] : null);
    }

    function pickMention(username) {
        const cursor = textareaRef.current?.selectionStart ?? text.length;
        const upToCursor = text.slice(0, cursor);
        const replaced = upToCursor.replace(/@(\w*)$/, `@${username} `);
        const newText = replaced + text.slice(cursor);
        setText(newText);
        setMentionQuery(null);
        requestAnimationFrame(() => textareaRef.current?.focus());
    }

    function insertEmoji(emoji) {
        const cursor = textareaRef.current?.selectionStart ?? text.length;
        const newText = text.slice(0, cursor) + emoji + text.slice(cursor);
        setText(newText);
        requestAnimationFrame(() => {
            textareaRef.current?.focus();
            textareaRef.current?.setSelectionRange(cursor + emoji.length, cursor + emoji.length);
        });
    }

    function handleSendText() {
        const trimmed = text.trim();
        if (!trimmed || disabled) return;
        onSendText(trimmed);
        setText('');
    }

    function handleSchedule(sendAt) {
        const trimmed = text.trim();
        if (!trimmed || disabled) return;
        onSchedule(trimmed, sendAt);
        setText('');
    }

    async function uploadAndSend(file) {
        setUploading(true);
        setProgress(0);
        try {
            const { data } = await uploadMedia(file, setProgress);
            onSendMedia(data.media_id, file.type);
        } catch (err) {
            alert(err.response?.data?.error || t('chat.input.uploadFailed'));
        } finally {
            setUploading(false);
            setProgress(0);
        }
    }

    async function handleFileChange(e) {
        const file = e.target.files?.[0];
        if (!file) return;
        e.target.value = '';
        await uploadAndSend(file);
    }

    async function startRecording() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            recordStreamRef.current = stream;
            recordChunksRef.current = [];

            const mr = new MediaRecorder(stream);
            mr.ondataavailable = e => { if (e.data.size) recordChunksRef.current.push(e.data); };
            mr.onstop = () => {
                stream.getTracks().forEach(tr => tr.stop());
                if (mr.cancelled) return;
                const blob = new Blob(recordChunksRef.current, { type: 'audio/webm' });
                const file = new File([blob], `voice-message-${Date.now()}.webm`, { type: 'audio/webm' });
                uploadAndSend(file);
            };

            mediaRecorderRef.current = mr;
            mr.start();
            setRecording(true);
            setRecordSeconds(0);
            recordTimerRef.current = setInterval(() => setRecordSeconds(s => s + 1), 1000);
        } catch {
            alert(t('chat.input.micPermissionDenied'));
        }
    }

    function stopRecording({ cancel = false } = {}) {
        clearInterval(recordTimerRef.current);
        setRecording(false);
        if (mediaRecorderRef.current) {
            mediaRecorderRef.current.cancelled = cancel;
            mediaRecorderRef.current.stop();
        }
    }

    return (
        <div className="border-t border-gray-700 bg-gray-800 px-4 py-3">
            {replyTarget && (
                <div className="mb-2 flex items-center justify-between bg-gray-700/60 rounded-lg px-3 py-2">
                    <div className="text-xs overflow-hidden">
                        <div className="text-indigo-300 font-medium">
                            {t('chat.input.replyingTo', { name: replyTarget.users?.full_name || t('common.unknown') })}
                        </div>
                        <div className="text-gray-400 truncate max-w-xs">
                            {replyTarget.type === 'text' ? replyTarget.content : t('common.media')}
                        </div>
                    </div>
                    <button onClick={onCancelReply} className="text-gray-400 hover:text-white text-sm flex-shrink-0 ml-2">✕</button>
                </div>
            )}
            {uploading && (
                <div className="mb-2">
                    <div className="flex justify-between text-xs text-gray-400 mb-1">
                        <span>{t('chat.input.uploading')}</span>
                        <span>{progress}%</span>
                    </div>
                    <div className="w-full bg-gray-700 rounded-full h-1">
                        <div className="bg-indigo-500 h-1 rounded-full transition-all" style={{ width: `${progress}%` }} />
                    </div>
                </div>
            )}

            {recording ? (
                <div className="flex items-center gap-3">
                    <button
                        onClick={() => stopRecording({ cancel: true })}
                        title={t('chat.input.cancelRecording')}
                        className="w-9 h-9 rounded-full bg-gray-700 hover:bg-red-900/60 flex items-center justify-center flex-shrink-0 transition-colors"
                    >
                        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                    <div className="flex-1 flex items-center gap-2 text-gray-300 text-sm">
                        <span className="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse" />
                        <span>{t('chat.input.recording')}</span>
                        <span className="text-gray-500">{formatRecordTime(recordSeconds)}</span>
                    </div>
                    <button
                        onClick={() => stopRecording({ cancel: false })}
                        title={t('chat.input.sendVoiceMessage')}
                        className="w-9 h-9 rounded-full bg-indigo-600 hover:bg-indigo-500 flex items-center justify-center flex-shrink-0 transition-colors"
                    >
                        <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                    </button>
                </div>
            ) : (
                <div className="flex items-end gap-2">
                    <EmojiButton onPick={insertEmoji} />

                    {/* Attach file */}
                    <button
                        onClick={() => fileRef.current?.click()}
                        disabled={disabled || uploading}
                        className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 disabled:opacity-40
                                   flex items-center justify-center flex-shrink-0 transition-colors"
                        title={t('chat.input.attachFile')}
                    >
                        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                        </svg>
                    </button>
                    <input ref={fileRef} type="file" accept={ACCEPT} onChange={handleFileChange} className="hidden" />

                    {/* Text area */}
                    <div className="flex-1 relative">
                        {mentionCandidates.length > 0 && (
                            <div className="absolute bottom-full mb-1 left-0 right-0 bg-gray-800 border border-gray-600 rounded-lg shadow-lg max-h-40 overflow-y-auto z-10">
                                {mentionCandidates.map(m => (
                                    <button
                                        key={m.username}
                                        onClick={() => pickMention(m.username)}
                                        className="w-full text-left px-3 py-1.5 hover:bg-gray-700 text-sm text-gray-200"
                                    >
                                        <span className="text-indigo-300">@{m.username}</span>
                                        {m.full_name && <span className="text-gray-500 ml-2">{m.full_name}</span>}
                                    </button>
                                ))}
                            </div>
                        )}
                        <textarea
                            ref={textareaRef}
                            value={text}
                            onChange={handleTextChange}
                            onKeyDown={handleKeyDown}
                            disabled={disabled || uploading}
                            placeholder={t('chat.input.placeholder')}
                            rows={1}
                            className="w-full bg-gray-700 border border-gray-600 rounded-2xl px-4 py-2.5
                                       text-white placeholder-gray-500 text-sm resize-none
                                       focus:outline-none focus:ring-2 focus:ring-indigo-500
                                       max-h-32 overflow-y-auto"
                            style={{ lineHeight: '1.4' }}
                        />
                    </div>

                    {/* Schedule */}
                    <SchedulePicker onSchedule={handleSchedule} />

                    {/* Send / voice message */}
                    {text.trim() ? (
                        <button
                            onClick={handleSendText}
                            disabled={disabled || uploading}
                            className="w-9 h-9 rounded-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-40
                                       flex items-center justify-center flex-shrink-0 transition-colors"
                        >
                            <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                    d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                            </svg>
                        </button>
                    ) : (
                        <button
                            onClick={startRecording}
                            disabled={disabled || uploading}
                            title={t('chat.input.voiceMessage')}
                            className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 disabled:opacity-40
                                       flex items-center justify-center flex-shrink-0 transition-colors"
                        >
                            <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                    d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3.75 3.75 0 003.75-3.75v-4.5a3.75 3.75 0 10-7.5 0v4.5A3.75 3.75 0 0012 15.75z" />
                            </svg>
                        </button>
                    )}
                </div>
            )}
        </div>
    );
}
