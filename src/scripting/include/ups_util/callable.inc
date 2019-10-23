/**
 * This file is a part of "Unified Punishment System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

methodmap Callable < Handle
{
    public Callable(Handle hPlugin, Function ptrCall)
    {
        DataPack hPack = new DataPack();
        hPack.WriteCell(hPlugin);
        hPack.WriteFunction(ptrCall);

        return view_as<Callable>(hPack);
    }

    property Handle Plugin
    {
        public get()
        {
            DataPack hPack = view_as<DataPack>(this);

            hPack.Reset();
            return hPack.ReadCell();
        }

        public set(Handle hPlugin)
        {
            DataPack hPack = view_as<DataPack>(this);

            hPack.Reset();
            hPack.WriteCell(hPlugin);
        }
    }

    property Function FuncPointer
    {
        public get()
        {
            DataPack hPack = view_as<DataPack>(this);

            hPack.Reset();
            hPack.ReadCell();
            return hPack.ReadFunction();
        }

        public set(Function ptrFunc)
        {
            DataPack hPack = view_as<DataPack>(this);

            hPack.Reset();
            hPack.ReadCell();
            hPack.WriteFunction(ptrFunc);
        }
    }

    public bool IsValid()
    {
        Handle hPlugin = this.Plugin;
        bool bValid = false;
        Handle hIter = GetPluginIterator();
        while (MorePlugins(hIter))
        {
            if (hPlugin == ReadPlugin(hIter))
            {
                bValid = true;
                break;
            }
        }

        hIter.Close();
        return bValid;
    }

    public void Start()
    {
        Call_StartFunction(this.Plugin, this.FuncPointer);
    }
}