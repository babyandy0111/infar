package model

import (
	"github.com/zeromicro/go-zero/core/stores/cache"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

var _ UserRolesModel = (*customUserRolesModel)(nil)

type (
	// UserRolesModel is an interface to be customized, add more methods here,
	// and implement the added methods in customUserRolesModel.
	UserRolesModel interface {
		userRolesModel
	}

	customUserRolesModel struct {
		*defaultUserRolesModel
	}
)

// NewUserRolesModel returns a model for the database table.
func NewUserRolesModel(conn sqlx.SqlConn, c cache.CacheConf, opts ...cache.Option) UserRolesModel {
	return &customUserRolesModel{
		defaultUserRolesModel: newUserRolesModel(conn, c, opts...),
	}
}
