export default function Avatar({ name, url, size = 'md' }) {
    const sz = size === 'sm' ? 'w-8 h-8 text-xs' : size === 'lg' ? 'w-20 h-20 text-2xl' : 'w-10 h-10 text-sm';
    const initials = name?.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '?';
    if (url) return <img src={url} alt={name} className={`${sz} rounded-full object-cover flex-shrink-0`} />;
    return (
        <div className={`${sz} rounded-full bg-indigo-700 flex items-center justify-center font-bold text-white flex-shrink-0`}>
            {initials}
        </div>
    );
}
