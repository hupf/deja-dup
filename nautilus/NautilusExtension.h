/* -*- Mode: C; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

#ifndef __NAUTILUSEXTENSION_H__
#define __NAUTILUSEXTENSION_H__

#include <glib.h>
#include <glib-object.h>

G_BEGIN_DECLS


#define TYPE_DEJA_DUP_NAUTILUS_EXTENSION (deja_dup_nautilus_extension_get_type ())
#define DEJA_DUP_NAUTILUS_EXTENSION(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_DEJA_DUP_NAUTILUS_EXTENSION, DejaDupNautilusExtension))
#define DEJA_DUP_NAUTILUS_EXTENSION_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_DEJA_DUP_NAUTILUS_EXTENSION, DejaDupNautilusExtensionClass))
#define IS_DEJA_DUP_NAUTILUS_EXTENSION(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_DEJA_DUP_NAUTILUS_EXTENSION))
#define IS_DEJA_DUP_NAUTILUS_EXTENSION_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_DEJA_DUP_NAUTILUS_EXTENSION))
#define DEJA_DUP_NAUTILUS_EXTENSION_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_DEJA_DUP_NAUTILUS_EXTENSION, DejaDupNautilusExtensionClass))

typedef struct _DejaDupNautilusExtension DejaDupNautilusExtension;
typedef struct _DejaDupNautilusExtensionClass DejaDupNautilusExtensionClass;
typedef struct _DejaDupNautilusExtensionPrivate DejaDupNautilusExtensionPrivate;

struct _DejaDupNautilusExtension {
	GObject parent_instance;
	DejaDupNautilusExtensionPrivate * priv;
};

struct _DejaDupNautilusExtensionClass {
	GObjectClass parent_class;
};


DejaDupNautilusExtension* deja_dup_nautilus_extension_construct (GType object_type);
DejaDupNautilusExtension* deja_dup_nautilus_extension_new (void);
GType deja_dup_nautilus_extension_get_type (void);


G_END_DECLS

#endif
