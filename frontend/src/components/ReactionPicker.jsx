import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import EmojiPicker from 'emoji-picker-react';

const FIXED_EMOJI = ['👍', '❤️', '😂', '😢', '😠'];

// Small popover: 5 fixed reactions + a "+" into the full emoji picker for
// arbitrary custom reactions. Used from MessageActions.
export default function ReactionPicker({ onSelect }) {
    const { t } = useTranslation();
    const [open, setOpen]         = useState(false);
    const [showFull, setShowFull] = useState(false);

    function pick(emoji) {
        onSelect(emoji);
        setOpen(false);
        setShowFull(false);
    }

    return (
        <div className="relative">
            <button
                onClick={() => setOpen(o => !o)}
                title={t('chat.actions.react')}
                className="w-6 h-6 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
            >
                <svg className="w-3.5 h-3.5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M9.172 16.172a4 4 0 005.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </button>

            {open && !showFull && (
                <div className="absolute z-20 bottom-8 right-0 bg-gray-800 border border-gray-600 rounded-xl shadow-lg p-2 flex items-center gap-1 whitespace-nowrap">
                    {FIXED_EMOJI.map(e => (
                        <button key={e} onClick={() => pick(e)} className="text-lg hover:scale-125 transition-transform">
                            {e}
                        </button>
                    ))}
                    <button onClick={() => setShowFull(true)} className="text-gray-400 hover:text-white text-sm px-1.5" title={t('chat.actions.moreEmoji')}>
                        +
                    </button>
                </div>
            )}

            {showFull && (
                <div className="absolute z-30 bottom-8 right-0">
                    <EmojiPicker onEmojiClick={d => pick(d.emoji)} width={300} height={350} />
                </div>
            )}
        </div>
    );
}
