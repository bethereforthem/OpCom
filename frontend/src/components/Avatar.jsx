export default function Avatar({ name, url, size = 'md', online = false }) {
    const sz = size === 'sm' ? 'w-8 h-8 text-xs' : size === 'lg' ? 'w-20 h-20 text-2xl' : 'w-10 h-10 text-sm';
    const initials = name?.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '?';
    return (
        <div className="relative inline-block flex-shrink-0">
            {url
                ? <img src={url} alt={name} className={`${sz} rounded-full object-cover`} />
                : <div className={`${sz} rounded-full bg-indigo-700 flex items-center justify-center font-bold text-white`}>
                    {initials}
                  </div>
            }
            {online && (
                <span className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-green-500 border-2 border-gray-800" />
            )}
        </div>
    );
}
