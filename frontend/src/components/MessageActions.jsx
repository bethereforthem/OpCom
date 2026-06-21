import { useTranslation } from 'react-i18next';
import ReactionPicker from './ReactionPicker';

// Hover-revealed action menu attached to a MessageBubble.
export default function MessageActions({ message, isMine, onEdit, onDelete, onReply, onForward, onReact }) {
    const { t } = useTranslation();
    const canEdit = isMine && message.type === 'text' && !message.is_deleted;
    const canDelete = isMine && !message.is_deleted;
    const canReply = !message.is_deleted;
    const canForward = !message.is_deleted;
    const canReact = !message.is_deleted;

    return (
        <div className="opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1 px-1">
            {canReact && <ReactionPicker onSelect={emoji => onReact(message, emoji)} />}
            {canForward && (
                <button
                    onClick={() => onForward(message)}
                    title={t('chat.actions.forward')}
                    className="w-6 h-6 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
                >
                    <svg className="w-3.5 h-3.5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M14 5l7 7m0 0l-7 7m7-7H3" />
                    </svg>
                </button>
            )}
            {canReply && (
                <button
                    onClick={() => onReply(message)}
                    title={t('chat.actions.reply')}
                    className="w-6 h-6 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
                >
                    <svg className="w-3.5 h-3.5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M9 17L4 12l5-5m11 12v-3a4 4 0 00-4-4H5" />
                    </svg>
                </button>
            )}
            {canEdit && (
                <button
                    onClick={() => onEdit(message)}
                    title={t('chat.actions.edit')}
                    className="w-6 h-6 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
                >
                    <svg className="w-3.5 h-3.5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                </button>
            )}
            {canDelete && (
                <button
                    onClick={() => onDelete(message)}
                    title={t('chat.actions.delete')}
                    className="w-6 h-6 rounded-full bg-gray-700 hover:bg-red-900/60 flex items-center justify-center transition-colors"
                >
                    <svg className="w-3.5 h-3.5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9.5 7V4.5A1.5 1.5 0 0111 3h2a1.5 1.5 0 011.5 1.5V7M4 7h16" />
                    </svg>
                </button>
            )}
        </div>
    );
}
